/*
 * Generates the "PLC Playground" OpenPLC Editor v4 project using the editor's
 * OWN rung-building functions (the same ones the GUI calls when you drop an
 * element on a placeholder), so the saved .ld files are exactly what the
 * editor itself would write.
 */
import { mkdirSync, writeFileSync } from 'fs'
import { join } from 'path'
import type { Edge, Node } from '@xyflow/react'
import { nodesBuilder, defaultCustomNodesStyles } from '../frontend/components/_atoms/graphical-editor/ladder/node-builders'
import { addNewElement } from '../frontend/components/_molecules/graphical-editor/ladder/rung/ladder-utils/elements'
import { renderPlaceholderElements } from '../frontend/components/_molecules/graphical-editor/ladder/rung/ladder-utils/elements/placeholder'
import type { RungLadderState } from '../frontend/store/slices'
import { serializePouToText } from '../frontend/utils/PLC/pou-text-serializer'
import type { PLCVariable } from '../middleware/shared/ports/types'

type Rung = RungLadderState
const OUT = process.env.PLAYGROUND_OUT || '/tmp/plc-playground'

// ---------------------------------------------------------------- rung helpers
function startRung(id: string, comment: string): Rung {
  const defaultBounds: [number, number] = [300, 100]
  const { powerRail } = defaultCustomNodesStyles
  const rails = [
    nodesBuilder.powerRail({ id: `left-rail-${id}`, posX: 0, posY: defaultBounds[1] / 2 - powerRail.height / 2, connector: 'right', handleX: powerRail.width, handleY: defaultBounds[1] / 2 }),
    nodesBuilder.powerRail({ id: `right-rail-${id}`, posX: defaultBounds[0], posY: defaultBounds[1] / 2 - powerRail.height / 2, connector: 'left', handleX: defaultBounds[0] - powerRail.width, handleY: defaultBounds[1] / 2 }),
  ]
  return {
    id, comment, defaultBounds, reactFlowViewport: defaultBounds, selectedNodes: [],
    nodes: [...rails] as Node[],
    edges: [{ id: `e_${rails[0].id}_${rails[1].id}`, source: rails[0].id, target: rails[1].id,
      sourceHandle: rails[0].data.handles[0].id, targetHandle: rails[1].data.handles[0].id, type: 'smoothstep' }] as Edge[],
  } as unknown as Rung
}

function place(rung: Rung, relatedId: string, position: 'left' | 'right' | 'bottom', elementType: string, blockVariant?: unknown) {
  const withPh = renderPlaceholderElements(rung) as Node[]
  const idx = withPh.findIndex((n) => (n.type === 'placeholder' || n.type === 'parallelPlaceholder')
    && (n.data as any).relatedNode?.id === relatedId && (n.data as any).position === position)
  if (idx < 0) throw new Error(`no ${position} placeholder for ${relatedId}`)
  const nodes = withPh.map((n, i) => (i === idx ? { ...n, selected: true } : n))
  const res = addNewElement({ ...rung, nodes } as Rung, { elementType, blockVariant })
  if (!res.newNode) throw new Error('addNewElement returned no node')
  return { rung: { ...rung, nodes: res.nodes, edges: res.edges } as Rung, id: res.newNode.id }
}

function patchNode(rung: Rung, id: string, dataPatch: Record<string, unknown>): Rung {
  return { ...rung, nodes: rung.nodes.map((n) => (n.id === id ? { ...n, data: { ...n.data, ...dataPatch } } : n)) } as Rung
}

class RungBuilder {
  rung: Rung
  last: string
  constructor(id: string, comment: string) {
    this.rung = startRung(id, comment)
    this.last = `left-rail-${id}`
  }
  private addRight(type: string, variant?: unknown) {
    const r = place(this.rung, this.last, 'right', type, variant)
    this.rung = r.rung
    this.last = r.id
    return r.id
  }
  contact(name: string, negated = false) {
    const id = this.addRight('contact')
    this.rung = patchNode(this.rung, id, { variable: { name }, ...(negated ? { variant: 'negated' } : {}) })
    return this
  }
  /** Contact in parallel (OR) with the most recently added element. */
  orContact(name: string, negated = false) {
    const r = place(this.rung, this.last, 'bottom', 'contact')
    this.rung = patchNode(r.rung, r.id, { variable: { name }, ...(negated ? { variant: 'negated' } : {}) })
    // continue in series AFTER the branch: the CLOSE junction of the new parallel
    const close = this.rung.nodes.find((n) => n.type === 'parallel' && (n.data as any).type === 'close'
      && this.rung.edges.some((e) => e.source === r.id && e.target === n.id))
    if (!close) throw new Error('parallel close not found')
    this.last = close.id
    return this
  }
  coil(name: string) {
    const id = this.addRight('coil')
    this.rung = patchNode(this.rung, id, { variable: { name } })
    return this
  }
  block(fbType: string, instance: string, variant: any, pins: Record<string, string>) {
    const id = this.addRight('block', variant)
    this.rung = patchNode(this.rung, id, {
      variable: { id: '', name: instance, type: { definition: 'derived', value: fbType }, class: 'local', location: '', documentation: '', debug: false },
    })
    const connected: unknown[] = []
    for (const [pin, value] of Object.entries(pins)) {
      const vnode = this.rung.nodes.find((n) => n.type === 'variable' && (n.data as any).block?.id === id && (n.data as any).block?.handleId === pin)
      if (!vnode) throw new Error(`no variable node for ${instance}.${pin}`)
      this.rung = patchNode(this.rung, vnode.id, { variable: { name: value } })
      const cls = variant.variables.find((v: any) => v.name === pin).class
      connected.push({ handleId: pin, type: cls, variable: { name: value } })
    }
    this.rung = patchNode(this.rung, id, { connectedVariables: connected })
    return this
  }
}

// ---------------------------------------------------------------- library FBs
const bool = { definition: 'base-type', value: 'BOOL' }
const time = { definition: 'base-type', value: 'TIME' }
const int = { definition: 'base-type', value: 'INT' }
const fb = (name: string, doc: string, vars: [string, string, object][]) => ({
  name, type: 'function-block', language: 'st', body: '', documentation: doc,
  variables: vars.map(([n, c, t]) => ({ name: n, class: c, type: t })),
})
const TON = fb('TON', 'On-delay timer: Q goes TRUE when IN has been TRUE for PT.', [['IN', 'input', bool], ['PT', 'input', time], ['Q', 'output', bool], ['ET', 'output', time]])
const TOF = fb('TOF', 'Off-delay timer: Q stays TRUE for PT after IN goes FALSE.', [['IN', 'input', bool], ['PT', 'input', time], ['Q', 'output', bool], ['ET', 'output', time]])
const CTU = fb('CTU', 'Up counter: CV counts rising edges of CU; Q when CV >= PV; R resets.', [['CU', 'input', bool], ['R', 'input', bool], ['PV', 'input', int], ['Q', 'output', bool], ['CV', 'output', int]])

// ---------------------------------------------------------------- variables
const v = (name: string, type: string, doc: string, init?: string, derived = false): PLCVariable => ({
  name, class: 'local', type: derived ? { definition: 'derived', value: type } : { definition: 'base-type', value: type },
  location: '', documentation: doc, debug: false, ...(init ? { initialValue: init } : {}),
} as unknown as PLCVariable)

type LdPou = { name: string; doc: string; vars: PLCVariable[]; rungs: Rung[]; debug: string[] }

function ldFile(p: LdPou): string {
  return serializePouToText({
    name: p.name, pouType: 'program', documentation: p.doc,
    interface: { variables: p.vars },
    body: { language: 'ld', value: { name: p.name, rungs: p.rungs } },
  } as any)
}

test('generate PLC Playground project', () => {
  const pous: LdPou[] = []

  // 1 -- start/stop with seal-in
  pous.push({
    name: 'P1_StartStop',
    doc: 'Start/stop with a seal-in. Click StartPB > Force True, then Force False: Motor stays on. Click StopPB_NC > Force False to stop.',
    vars: [
      v('StartPB', 'BOOL', 'Start push-button, NO: TRUE while pressed'),
      v('StopPB_NC', 'BOOL', 'Stop push-button, NC: TRUE while NOT pressed (a healthy stop circuit)', 'TRUE'),
      v('Motor', 'BOOL', 'Motor contactor'),
      v('RunLamp', 'BOOL', 'Green running lamp'),
    ],
    rungs: [
      new RungBuilder('rung_P1_1', 'Seal-in: Start switches the motor on, the Motor contact below Start keeps it on, Stop breaks the circuit.')
        .contact('StartPB').orContact('Motor').contact('StopPB_NC').coil('Motor').rung,
      new RungBuilder('rung_P1_2', 'The run lamp simply follows the motor.')
        .contact('Motor').coil('RunLamp').rung,
    ],
    debug: ['StartPB', 'StopPB_NC', 'Motor', 'RunLamp'],
  })

  // 2 -- on-delay and off-delay timers
  pous.push({
    name: 'P2_Timers',
    doc: 'Timers. Hold DelayPB TRUE for 3 s and DelayLamp lights (watch DelayET count). Turn FanSwitch TRUE then FALSE: Fan runs on for 5 s.',
    vars: [
      v('DelayPB', 'BOOL', 'Push-button that must be held for 3 s'),
      v('DelayLamp', 'BOOL', 'Lights after DelayPB has been held for 3 s'),
      v('DelayTimer', 'TON', 'On-delay timer instance', undefined, true),
      v('DelayET', 'TIME', 'Elapsed time of DelayTimer'),
      v('FanSwitch', 'BOOL', 'Fan on/off switch'),
      v('Fan', 'BOOL', 'Fan motor: keeps running 5 s after FanSwitch goes off'),
      v('RunOnTimer', 'TOF', 'Off-delay timer instance', undefined, true),
      v('RunOnET', 'TIME', 'Elapsed time of RunOnTimer'),
    ],
    rungs: [
      new RungBuilder('rung_P2_1', 'On-delay (TON): DelayLamp comes on only after DelayPB has been TRUE for 3 s. Release early and the timer resets.')
        .contact('DelayPB').block('TON', 'DelayTimer', TON, { PT: 'T#3s', ET: 'DelayET' }).coil('DelayLamp').rung,
      new RungBuilder('rung_P2_2', 'Off-delay (TOF): Fan starts at once, and after FanSwitch goes FALSE it runs on for 5 s (like a bathroom fan).')
        .contact('FanSwitch').block('TOF', 'RunOnTimer', TOF, { PT: 'T#5s', ET: 'RunOnET' }).coil('Fan').rung,
    ],
    debug: ['DelayPB', 'DelayLamp', 'DelayET', 'FanSwitch', 'Fan', 'RunOnET'],
  })

  // 3 -- self-running flasher
  pous.push({
    name: 'P3_Flasher',
    doc: 'A flashing beacon made from two timers. It runs by itself as soon as the simulator starts. Force Enable FALSE to stop it.',
    vars: [
      v('Enable', 'BOOL', 'Beacon enabled', 'TRUE'),
      v('OnTimer', 'TON', 'Times the lit half of the cycle', undefined, true),
      v('OffTimer', 'TON', 'Times the dark half of the cycle', undefined, true),
      v('OnDone', 'BOOL', 'Lit half finished'),
      v('OffDone', 'BOOL', 'Dark half finished'),
      v('Beacon', 'BOOL', 'Flashing beacon: 0.5 s on, 0.5 s off'),
    ],
    rungs: [
      new RungBuilder('rung_P3_1', 'OnTimer runs while the cycle is in its first half. OffDone resets it at the end of each cycle.')
        .contact('Enable').contact('OffDone', true).block('TON', 'OnTimer', TON, { PT: 'T#500ms' }).coil('OnDone').rung,
      new RungBuilder('rung_P3_2', 'When the first half is done, OffTimer times the second half.')
        .contact('OnDone').block('TON', 'OffTimer', TON, { PT: 'T#500ms' }).coil('OffDone').rung,
      new RungBuilder('rung_P3_3', 'The beacon is lit during the first half of each cycle.')
        .contact('Enable').contact('OnDone', true).coil('Beacon').rung,
    ],
    debug: ['Enable', 'OnDone', 'OffDone', 'Beacon'],
  })

  // 4 -- counter
  pous.push({
    name: 'P4_Counter',
    doc: 'Counting bottles. Toggle BottleSensor TRUE/FALSE five times: Count goes 1..5 and BoxFull comes on. Pulse ResetPB to start again.',
    vars: [
      v('BottleSensor', 'BOOL', 'Photo-eye: TRUE while a bottle passes'),
      v('ResetPB', 'BOOL', 'Reset push-button'),
      v('BottleCounter', 'CTU', 'Up-counter instance', undefined, true),
      v('Count', 'INT', 'Bottles counted'),
      v('BoxFull', 'BOOL', 'TRUE when 5 bottles have been counted'),
    ],
    rungs: [
      new RungBuilder('rung_P4_1', 'CTU counts each FALSE-to-TRUE change of BottleSensor. At 5 (PV) the box is full. ResetPB sets the count back to 0.')
        .contact('BottleSensor').block('CTU', 'BottleCounter', CTU, { R: 'ResetPB', PV: '5', CV: 'Count' }).coil('BoxFull').rung,
    ],
    debug: ['BottleSensor', 'ResetPB', 'Count', 'BoxFull'],
  })

  // ---------------------------------------------------------------- write project
  const root = OUT
  mkdirSync(join(root, 'pous', 'programs'), { recursive: true })
  mkdirSync(join(root, 'devices'), { recursive: true })
  for (const p of pous) writeFileSync(join(root, 'pous', 'programs', `${p.name}.ld`), ldFile(p))

  // 5 -- tank level (Structured Text, a small process simulation)
  const tankVars = [
    v('Level', 'REAL', 'Tank level in % (simulated)', '50.0'),
    v('InletPump', 'BOOL', 'Pump filling the tank'),
    v('OutletOpen', 'BOOL', 'Outlet valve: the plant is using water', 'TRUE'),
    v('StartLevel', 'REAL', 'Pump starts at or below this level (%)', '20.0'),
    v('StopLevel', 'REAL', 'Pump stops at or above this level (%)', '80.0'),
    v('HighAlarm', 'BOOL', 'Level at or above 90 %'),
  ]
  const tankBody = [
    '(* 1. CONTROL: on/off level control with hysteresis.',
    '   The pump starts at StartLevel and keeps running until StopLevel. *)',
    'IF Level <= StartLevel THEN',
    '  InletPump := TRUE;',
    'ELSIF Level >= StopLevel THEN',
    '  InletPump := FALSE;',
    'END_IF;',
    'HighAlarm := Level >= 90.0;',
    '',
    '(* 2. SIMULATED PLANT: in a real plant this part is the tank itself.',
    '   The pump adds 0.1 % per scan, the open outlet removes 0.04 % per scan. *)',
    'IF InletPump THEN',
    '  Level := Level + 0.1;',
    'END_IF;',
    'IF OutletOpen THEN',
    '  Level := Level - 0.04;',
    'END_IF;',
    'Level := LIMIT(0.0, Level, 100.0);',
  ].join('\n')
  writeFileSync(join(root, 'pous', 'programs', 'P5_TankLevel.st'), serializePouToText({
    name: 'P5_TankLevel', pouType: 'program',
    documentation: 'A tank filled by a pump with on/off (hysteresis) control. Runs by itself: plot Level in the debugger to see it rise and fall between 20 % and 80 %. Force StopLevel higher to see HighAlarm.',
    interface: { variables: tankVars }, body: { language: 'st', value: tankBody },
  } as any))

  const names = [...pous.map((p) => p.name), 'P5_TankLevel']
  const project = {
    meta: { name: 'PLC-Playground', type: 'plc-project' },
    data: {
      pous: [], dataTypes: [], libraries: [],
      configuration: { resource: {
        tasks: [{ name: 'MainTask', triggering: 'Cyclic', interval: 'T#20ms', priority: 1 }],
        instances: names.map((n, i) => ({ name: `Inst${i + 1}_${n.split('_')[1]}`, program: n, task: 'MainTask' })),
        globalVariables: [],
      } },
      debugVariables: { pous: Object.fromEntries([...pous.map((p) => [p.name, p.debug]),
        ['P5_TankLevel', ['Level', 'InletPump', 'OutletOpen', 'HighAlarm']]]) },
    },
  }
  writeFileSync(join(root, 'project.json'), JSON.stringify(project, null, 2))
  writeFileSync(join(root, 'devices', 'configuration.json'), JSON.stringify({
    deviceBoard: 'OpenPLC Simulator', communicationPort: '', runtimeIpAddress: '', vendorScreenData: {},
    vendorScreenDataByBoard: {}, persistentStorage: { enabled: false, path: '', flushSeconds: 5 },
    persistentStorageByBoard: {}, selectedPlatformOptions: {},
  }, null, 2))
  writeFileSync(join(root, 'devices', 'pin-mapping.json'), '{}')
  console.log('written to ' + root)
})
