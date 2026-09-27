# Appendix D — Resources, Standards and Certifications

A curated guide for after the course: software to practise on, books worth owning, the
standards you will be asked about, free training, communities, the certifications and
registrations employers recognise, and how to turn your capstone work into a portfolio.

Two warnings first:

- **Things change.** Product names, licence terms, trial lengths, qualification codes and
  standard editions all move. Everything here was checked at the time of writing (2026), but
  confirm the current position on the owner's website before you rely on it. For the same
  reason, no prices are given.
- **Only use official copies.** Cracked engineering software is a well-known route for
  malware, and you do not want that on a laptop that will later connect to a control network.
  Pirated standards are often old editions too. The free and trial routes below are enough for
  everything in this course.

If you only do three things from this appendix:

1. Install one industrial IDE (CODESYS is the easiest free choice) next to OpenPLC, and redo a
   few labs in it.
2. Download the PLCopen *Coding Guidelines* and your main vendor's programming guideline, and
   read them against your own lab solutions.
3. Put one capstone project in a git repository with a proper write-up (section D.7).

## D.1 Free software and simulators

### D.1.1 Open-source tools

| Tool | What it is |
|---|---|
| **`plctest` + MATIEC** (this course) | The test runner in `tools/`, built on the open-source MATIEC IEC 61131-3 compiler. See [Appendix E](E-matiec-openplc-notes.md) |
| **OpenPLC Editor and Runtime** (Autonomy Logic) | A free, open-source PLC. The Editor is an IEC 61131-3 IDE (Ladder and Structured Text, plus other IEC languages; exactly which depends on the version). The Runtime turns a PC, a Raspberry Pi or other supported hardware into a controller |
| **Beremiz** | The open-source IEC 61131-3 IDE that MATIEC comes from |
| **Eclipse 4diac** | An open-source IDE (4diac IDE) and runtime (4diac FORTE) for **IEC 61499**, the event-driven, distributed function-block standard |

OpenPLC has recently been redesigned. The **v4** Editor is a new desktop application for
Windows, Linux and macOS, and the **v4** Runtime is "headless": you control it from the Editor
(or Autonomy's cloud service) rather than from its own web page. Many tutorials still show the
older **v3** Runtime with its built-in web interface, so check which version a tutorial uses.
The documentation is on the Autonomy Logic website and the source code is on GitHub.

### D.1.2 Industrial IDEs you can use free or on trial

These are the tools used on real plant. All run on Windows, and most need you to register an
account before you can download them.

| Tool | Maker | What you get free | Notes |
|---|---|---|---|
| **CODESYS Development System V3** | CODESYS Group | The full IDE, from the CODESYS Store. The *CODESYS Control Win SL* soft PLC runs in demo mode without a licence for two hours at a time, then you restart it | The best free route to the full IEC 61131-3 edition 3 language, including OOP. Many hardware brands use CODESYS under their own names. A Raspberry Pi runtime also exists, with a similar time-limited demo mode |
| **TwinCAT 3** | Beckhoff | The engineering environment (XAE) is free. Runtime and add-on functions need licences, but you can generate **7-day trial licences** in the IDE and renew them as often as you like | TwinCAT's PLC environment is based on CODESYS, so the skills transfer directly |
| **TIA Portal: STEP 7, WinCC, S7-PLCSIM** | Siemens | A time-limited trial (21 days at the time of writing) that includes STEP 7, WinCC and PLCSIM | PLCSIM simulates S7-1200/1500 CPUs. The ST dialect is called SCL. Download through Siemens' SiePortal. S7-PLCSIM Advanced is a separate product for more demanding simulation |
| **Connected Components Workbench (CCW) Standard Edition** | Rockwell Automation | Free, for Micro800 controllers, with a demo version of the Micro800 simulator that runs for limited periods | The paid Developer Edition has the full simulator |
| **Studio 5000 Logix Designer** | Rockwell Automation | Not free | For ControlLogix/CompactLogix. Emulation needs FactoryTalk Logix Echo (or the older Logix Emulate). Many employers and colleges hold licences |
| **EcoStruxure Machine Expert – Basic** | Schneider Electric | Free, for Modicon M221 controllers | Schneider's larger *Machine Expert* is CODESYS-based |
| **CLICK Programming Software**, **Do-more Designer** | AutomationDirect | Both free. Do-more Designer has a built-in simulator | Ladder-centred and approachable. Hardware availability outside North America varies |

Two tips. **Plan your trials**: a 21-day trial vanishes if you install it and then go on
holiday, so install it when you have study time set aside. **Ask your employer**: a company
that uses a platform may have spare licences, a training rig or a test controller you can use.
A virtual machine keeps large vendor IDEs apart, but some real-time runtimes (TwinCAT, for
example) have restrictions on virtualisation, so read the installation notes first.

### D.1.3 Plant, machine and HMI simulators

- **Factory I/O** (Real Games): 3D conveyors, sorters, tanks and warehouses that you drive
  from a real PLC, a simulator or a soft PLC. Paid, in several editions for different PLC
  families, with a free full-featured trial (30 days at the time of writing). It suits the
  conveyor capstone ([24-1](../24-capstone-projects/24-1-conveyor-sorting-cell.md)).
- **FluidSIM** (Festo Didactic): design and simulation of pneumatic, hydraulic and electrical
  circuits, widely used in colleges. Commercial, with several licence options; Festo offers a
  trial licence through a Festo account.
- **Ignition** (Inductive Automation): an HMI/SCADA platform with a free trial mode (the
  runtime works in two-hour sessions that you can restart). The **Maker Edition** is free for
  personal, non-commercial use. Connect it to OpenPLC over Modbus TCP, or to CODESYS over
  Modbus TCP or OPC UA, to practise [Module 18](../18-hmi-and-scada/).

### D.1.4 Supporting tools

- **Git** and a hosting service (GitHub, GitLab or similar) for version control and your
  portfolio ([Module 22](../22-software-engineering/)).
- **VS Code** or another good editor, with a Structured Text syntax extension.
- **Wireshark**, the free network analyser, which decodes Modbus, PROFINET, EtherNet/IP and
  many other industrial protocols ([Module 17](../17-industrial-communications/)).
- A free **Modbus master/slave test tool**, to prove a link works before you blame your code.

## D.2 Books

**Free** marks books that are legitimately free from the author or publisher. Editions are
given where they have been checked. Newer ones may exist.

### D.2.1 PLC fundamentals

- **Frank D. Petruzella, *Programmable Logic Controllers*** (McGraw Hill; now in its sixth
  edition). A standard North-American college text, very clear on hardware, wiring and
  ladder basics. Its examples lean towards Allen-Bradley.
- **W. Bolton, *Programmable Logic Controllers*** (Newnes/Elsevier; sixth edition, 2015). A
  compact, vendor-neutral British text with worked examples and problems. A good second
  explanation of anything in Levels 1–2.
- **Hugh Jack, *Automating Manufacturing Systems with PLCs*** (**Free**, under an open
  licence; on the Internet Archive and open-textbook sites). A broad university text: logic
  design, state-based and sequential design, the IEC languages, sensors, actuators and
  networks. Its hardware examples are mostly Allen-Bradley, and the widely circulated version
  (5.1) dates from 2008, so the vendor material is dated; the logic-design chapters have aged
  well.
- **Tony R. Kuphaldt, *Lessons In Industrial Instrumentation*** (**Free**, Creative Commons
  licence). An open textbook for instrument technician training: 4–20 mA loops, transmitters,
  control valves, PID, safety systems and digital networks. If you come from the
  instrumentation side, this is the book that joins your world to this course.

### D.2.2 IEC 61131-3 and vendor platforms

- **Karl-Heinz John and Michael Tiegelkamp, *IEC 61131-3: Programming Industrial Automation
  Systems*** (Springer; second edition, 2010). The classic walk-through of the standard's
  software model, data types, POUs and languages. It predates edition 3, so it does not cover
  the object-oriented features ([Module 21](../21-architecture-and-standards/)).
- **Hans Berger, *Automating with SIMATIC S7-1500*** and ***Automating with SIMATIC
  S7-1200*** (Publicis; several editions). Detailed books on configuring and programming
  current Siemens controllers in TIA Portal, including SCL. Berger's older STEP 7 books cover
  the S7-300/400 generation.
- For Rockwell, CODESYS and Beckhoff, the vendor manuals (D.4) beat any book.

### D.2.3 Process control and instrumentation

- **K. J. Åström and T. Hägglund, *Advanced PID Control*** (ISA, 2006), and their earlier
  ***PID Controllers: Theory, Design, and Tuning*** (ISA, 1995). The standard references on
  PID forms, anti-windup and tuning ([Module 15](../15-pid-control/)).
- **Myke King, *Process Control: A Practical Approach*** (Wiley; second edition, 2016). By a
  practitioner who trains plant engineers. The heavy mathematics is kept to the back, and the
  focus is on what works on real process units.
- **Béla G. Lipták (ed.), *Instrument Engineers' Handbook*** (CRC Press, multi-volume). A
  reference to dip into, not to read cover to cover.

### D.2.4 Alarm management and HMI

- **Bill R. Hollifield and Eddie Habibi, *Alarm Management: A Comprehensive Guide*** (ISA;
  second edition, 2010). Rationalisation, alarm KPIs and bad-actor reduction, aligned with
  ISA-18.2 ([Module 16](../16-alarms-and-diagnostics/)).
- **Bill Hollifield, Dana Oliver, Ian Nimmo and Eddie Habibi, *The High Performance HMI
  Handbook*** (PAS, 2008). The best-known book on "high-performance" operator displays: muted
  backgrounds, with colour kept for abnormal conditions ([Module 18](../18-hmi-and-scada/)).

### D.2.5 Functional safety and process safety

- **David J. Smith and Kenneth G. L. Simpson, *The Safety Critical Systems Handbook: A
  Straightforward Guide to Functional Safety*** (Butterworth-Heinemann; fifth edition, 2020).
  A readable British guide to IEC 61508 and IEC 61511, with worked examples.
- **Paul Gruhn and Harry Cheddie, *Safety Instrumented Systems: Design, Analysis, and
  Justification*** (ISA; second edition, 2006), and the later **Paul Gruhn and Simon
  Lucchini, *Safety Instrumented Systems: A Life-Cycle Approach*** (ISA, 2018). Practical SIS
  design across the lifecycle.
- **Trevor Kletz, *What Went Wrong? Case Histories of Process Plant Disasters and How They
  Could Have Been Avoided*** (Butterworth-Heinemann; fifth edition, 2009). Short, memorable accident case histories. It will change how you think about
  "temporary" bypasses and modifications.
- **HSE, HSG238 *Out of control: Why control systems go wrong and how to prevent failure***
  (**Free** from the HSE website). Real control-system incidents, analysed by lifecycle phase.
  It makes the case for [Module 20](../20-functional-safety/) better than any textbook.
- **Rockwell Automation, *Machinery Safebook*** (**Free**). An illustrated guide to machinery
  functional safety (ISO 13849-1, IEC 62061). Other safety-component makers publish similar
  free guides.
- The LOPA book and other references in [Module 20](../20-functional-safety/#further-reading).

### D.2.6 Industrial cyber security

- **Eric D. Knapp and Joel Thomas Langill, *Industrial Network Security*** (Syngress; second
  edition, 2014). Industrial protocols, zoning and defence in depth, written from the OT side
  ([Module 22](../22-software-engineering/)).

## D.3 Standards

### D.3.1 The standards you should recognise

You do not need to own these. You do need to know what each is for, so that you recognise it
in a specification and know where to look.

| Standard | What it covers | Course |
|---|---|---|
| **IEC 61131-3** | PLC programming languages (LD, FBD, ST, IL and SFC elements), data types, POUs and the software model. Tools implement edition 2 (2003) or edition 3 (2013); edition 3 added object orientation and deprecated IL. A fourth edition was published in 2025, and its Annex B lists what was added, removed and deprecated | [03](../03-data-types-and-addressing/)–[13](../13-sequential-control/), [21](../21-architecture-and-standards/) |
| **IEC 61131-2** | PLC equipment requirements and tests: power supplies, digital and analog I/O characteristics, environmental and EMC tests | [01](../01-what-is-a-plc/), [02](../02-electrical-and-field-devices/) |
| **IEC 61499** | Event-driven function blocks for distributed control across several devices. Worth knowing about; Eclipse 4diac is a free way to try it | — |
| **IEC 60204-1** | Electrical equipment of machines: stop categories 0, 1 and 2, emergency stop, control circuits, protective bonding, documentation. North-American counterpart: **NFPA 79** | [02](../02-electrical-and-field-devices/), [19](../19-motion-and-drives/), [20](../20-functional-safety/) |
| **IEC 61508** | Functional safety of electrical/electronic/programmable electronic safety-related systems. The seven-part "umbrella" standard: used directly by makers of safety devices, and the basis of sector standards such as IEC 61511 and IEC 62061 | [20](../20-functional-safety/) |
| **IEC 61511** | Safety instrumented systems for the process industry: the SIS lifecycle, SIL, proof testing, bypasses, management of change. In the USA, ANSI/ISA-61511 (earlier ANSI/ISA-84.00.01) | [20](../20-functional-safety/), [23](../23-commissioning-and-troubleshooting/) |
| **ISO 13849-1** | Safety-related parts of machine control systems: performance levels PL a–e and categories. Part 2 covers validation | [20](../20-functional-safety/) |
| **IEC 62061** | Functional safety of safety-related control systems for machinery, using SIL 1–3 | [20](../20-functional-safety/) |
| **IEC 62443** (series) | Security for industrial automation and control systems: zones and conduits, security levels, and requirements for asset owners, integrators and product suppliers | [17](../17-industrial-communications/), [22](../22-software-engineering/) |
| **ISA-88 / IEC 61512** | Batch control: physical, procedural and recipe models, and procedural states | [13](../13-sequential-control/), [21](../21-architecture-and-standards/) |
| **ISA-95 / IEC 62264** | Enterprise-control integration: the levels model and the information exchanged between control, MES and business systems | [21](../21-architecture-and-standards/) |
| **ISA-18.2 / IEC 62682** | Management of alarm systems for the process industries: lifecycle, philosophy, rationalisation, performance monitoring | [16](../16-alarms-and-diagnostics/) |
| **EEMUA 191** | *Alarm systems: a guide to design, management and procurement*. The long-established UK industry guide (fourth edition, 2024), widely used alongside ISA-18.2 | [16](../16-alarms-and-diagnostics/) |
| **ISA-101.01** | HMIs for process automation systems: HMI lifecycle, style guides, display hierarchy. IEC 63303 is based on it | [18](../18-hmi-and-scada/) |
| **ISA-5.1** | Instrumentation symbols and identification: the tag letters and symbols on P&IDs and loop drawings | [02](../02-electrical-and-field-devices/), [08](../08-counters/) |
| **NAMUR NE 43** | Signal levels for failure information from transmitters: which 4–20 mA values mean "measurement" and which mean "fault" | [14](../14-analog-and-process-io/) |
| **IEC 60079** (series) | Explosive atmospheres: protection concepts (Ex d, Ex e, intrinsic safety Ex i and others), area classification, installation, inspection and maintenance. Published in the UK as BS EN 60079 | [02](../02-electrical-and-field-devices/) |
| **IEC 81346** (series) | Structuring principles and reference designations: the `=`, `-` and `+` prefixes for function, product and location, and letter codes for classes of object | [02](../02-electrical-and-field-devices/) |
| **BS 7671** | *Requirements for Electrical Installations* (the IET Wiring Regulations), the UK standard for electrical installations. The 18th Edition (BS 7671:2018) is current, updated by amendments; the latest at the time of writing is Amendment 4:2026 | [02](../02-electrical-and-field-devices/) |
| **NFPA 70E** | Electrical safety in the workplace (USA): shock and arc-flash risk assessment, energised work, PPE. In Europe, EN 50110 covers the operation of electrical installations | [02](../02-electrical-and-field-devices/), [23](../23-commissioning-and-troubleshooting/) |

### D.3.2 Others you will meet

- **ISO 12100** (machinery risk assessment), **ISO 13850** (emergency stop), **IEC 61800-5-2**
  (safety functions in drives), **IEC 62381** and **IEC 62382** (FAT/SAT and loop checks,
  [Module 23](../23-commissioning-and-troubleshooting/)), **ISA-TR88.00.02** (PackML) and
  **NFPA 70** (the US National Electrical Code).
- **UK law sits above all of these.** Standards are how you show you have met the law, but the
  duties come from regulations such as the Electricity at Work Regulations 1989, PUWER 1998
  (work equipment), DSEAR 2002 (explosive atmospheres) and, on major hazard sites, COMAH 2015.
  The HSE publishes free guidance on each, for example HSR25 on the Electricity at Work
  Regulations.

### D.3.3 How to read a standard

1. **Read the scope first**: what the standard applies to and, just as important, what it
   does not. Then check the edition, and which edition your project documents call up.
2. **Know the verbs.** In IEC and ISO standards "shall" is a requirement, "should" a
   recommendation, "may" a permission and "can" a possibility.
3. **Separate normative from informative.** Notes, examples and informative annexes explain;
   they are not requirements.
4. **Read the definitions**, and look for the guidance part of a series: IEC 61511-2, for
   example, explains how to apply IEC 61511-1.

### D.3.4 How to get access

Most standards are sold, not free. Routes, cheapest first:

- **Your employer.** Many companies subscribe to British Standards Online (BSOL) or a similar
  service, or hold the standards their projects call up. Ask your document controller. This
  is the most common route.
- **Libraries.** Many UK university libraries subscribe to BSOL. Some large reference
  libraries also provide access, so ask.
- **Free previews.** The IEC webstore offers a free preview of each publication, usually
  including the contents and scope: often enough to decide whether you need it.
- **Free read-only access.** NFPA lets anyone read its codes and standards, including
  NFPA 70E, online after registering.
- **Membership.** ISA members can view most ISA standards online, read-only, for their own
  use. EEMUA publications are available to EEMUA member companies and can be bought by
  others. NAMUR recommendations are available to members; non-members can buy individual
  documents.
- **Buying.** BSI sells BS EN versions of IEC and ISO standards, with discounts for BSI
  members. A BS EN standard usually has the same technical content as the IEC or ISO text plus
  a national foreword and, where relevant, a European annex. The IEC webstore, ISO and ISA
  sell directly, and the IET sells BS 7671 with its *On-Site Guide* and *Guidance Notes*.

## D.4 Free online training and documentation

### D.4.1 Vendor material

- **Siemens SCE learn/training documents.** Siemens Automation Cooperates with Education (SCE)
  publishes over a hundred free training modules, many of them for TIA Portal, from first
  steps with an S7-1200 or S7-1500 to advanced topics, with exercise projects, in several
  languages. You need a free Siemens (SiePortal) account to download them. Written for
  colleges, they suit self-study well.
- **Siemens SiePortal (Industry Online Support)**: manuals, plus the *Programming Guideline*
  and *Programming Styleguide* for S7-1200/S7-1500
  ([Module 10](../10-structured-text/#further-reading)).
- **Rockwell Literature Library**: user manuals, the Logix 5000 programming manuals and
  instruction references, free. The Rockwell Knowledgebase (technotes) is on the support
  site; some articles need a support contract. **Learning+** is Rockwell's paid e-learning
  subscription, if your employer offers it.
- **CODESYS Online Help** covers the IDE, the languages (including OOP) and the standard
  libraries. **CODESYS Forge** hosts community projects and forums. The **CODESYS Academy**
  runs paid courses.
- **Beckhoff Information System (InfoSys)**: the complete, free online documentation for
  TwinCAT and Beckhoff hardware, with library references and examples.
- **OpenPLC documentation** on the Autonomy Logic website.
- **Inductive University**: free, self-paced video courses for Ignition.

### D.4.2 Vendor-neutral material

- **PLCopen** (plcopen.org), free: the *Coding Guidelines* (rules for naming, comments and
  structure in IEC 61131-3 code), the *Motion Control* function-block specifications
  ([Module 19](../19-motion-and-drives/)), the *Safety* specifications
  ([Module 20](../20-functional-safety/)) and the XML exchange format.
- **ISA** (isa.org): articles, technical papers and webinars, many of them free.
- **UK HSE** (hse.gov.uk): free guidance including HSG238 *Out of control*, HSG253 *The safe
  isolation of plant and equipment* and HSR25. HSE investigation reports on major incidents
  are some of the best safety reading there is.
- **Security:** the *Top 20 Secure PLC Coding Practices* (plc-security.com), the UK National
  Cyber Security Centre's guidance on operational technology, and the US CISA's ICS
  advisories, which show real vulnerabilities in real products.
- **Protocol organisations** (Modbus Organization, PI, ODVA, OPC Foundation): free
  overviews and guides, and in some cases the specifications themselves (the Modbus
  specifications, for example, are free to download; some organisations keep full
  specifications for members or sell them)
  ([Module 17](../17-industrial-communications/#further-reading)).

### D.4.3 Video

Most vendors run YouTube channels, and many independent trainers publish PLC tutorials.
Quality varies. A good video names the software version, shows the whole procedure, and
explains *why* as well as *how*. Treat any video that forces outputs or bypasses safety
devices on live plant as a warning, not an example.

## D.5 Communities

| Community | Good for |
|---|---|
| **PLCtalk** (plctalk.net) | A long-established, very active PLC Q&A forum covering many brands (with a lot of Allen-Bradley discussion), and regulars who have decades of plant experience. Search before you post |
| **r/PLC** (Reddit) | A large, informal community: career questions, "what would you do?" threads, panels good and bad |
| **Siemens forum** (on SiePortal) | Siemens' official community forum, for TIA Portal, SCL and PROFINET questions |
| **Rockwell community** (currently branded *Engage*) | Rockwell's own user community |
| **CODESYS Forge** forums | CODESYS questions, libraries and projects |
| **Beckhoff InfoSys** | Documentation rather than a forum, but the first place to look for TwinCAT answers |
| **OpenPLC forum** (linked from the Autonomy Logic website) | Installation, hardware and Runtime questions |
| **Mr PLC** (mrplc.com), **Control.com** | Further general forums, with sections for many brands |
| **InstMC, IET** (and ISA, where it has a local section) | Local events and technical talks, where you meet the people who hire |

To get good answers, give the platform, software version, CPU and firmware; say what you
expected, what happened and what you tried; and post the smallest piece of code that shows
the problem. **Never post anything that identifies a real site**: company names, IP
addresses, network drawings, passwords or photos with plant labels. Use generic tag names.
That is good security practice and usually a contractual duty too.

## D.6 Certifications and career paths

### D.6.1 Know what you are getting

| Term | What it means | Example |
|---|---|---|
| **Attendance certificate** | You attended a course | Most vendor courses |
| **Certificate programme** | A defined course of study with an assessment | ISA's IEC 61511 and IEC 62443 programmes |
| **Certification** | Independent assessment against a published scheme, usually with experience requirements and renewal | ISA CCST, CFSE, TÜV functional safety certificates, CompEx |
| **Skills card** | Proof of qualifications and safety training for site access | ECS card |
| **Professional registration** | A protected title awarded after peer review of your competence | EngTech, IEng, CEng |

None of these is a legal licence to program PLCs, and no single certificate makes you
competent. Standards such as IEC 61511 require people working on safety systems to be
competent for their tasks, and employers show that through qualifications, experience,
supervision and records together. Certifications are good evidence within that mix.

### D.6.2 Vendor certifications

These show platform skill. Describe them accurately on a CV.

- **Siemens:** SITRAIN, Siemens' training organisation, offers the **Siemens Certified
  Programmer in TIA Portal**: a practical examination on a hardware training rig, which can
  be booked together with a preparation course.
- **Rockwell Automation** runs **certificate programmes** for roles such as Logix 5000
  programmer and maintainer: a set of Rockwell courses followed by a final assessment.
- **Inductive Automation** offers Ignition certification tests (Core, then Gold); the free
  Inductive University courses prepare you for them. **CODESYS** (through the CODESYS
  Academy) and **Beckhoff** run their own paid training courses.

Employers often pay for vendor training, so ask for it in a job offer or development review.

### D.6.3 ISA

The International Society of Automation runs two certifications, recognised internationally
but best known in North America:

- **Certified Control Systems Technician (CCST)**, in three levels: Level I, Level II
  (Specialist) and Level III (Master), each needing more years of education, training and
  experience. It covers calibrating, documenting, troubleshooting and repairing
  instrumentation and control systems: a close match to instrument technician work.
- **Certified Automation Professional (CAP)**, for engineers responsible for the design,
  deployment and support of automation systems.

Its course-based certificate programmes are:

- **ISA/IEC 61511**: SIS Fundamentals Specialist, SIL Selection Specialist and SIL
  Verification Specialist; all three together earn the ISA/IEC 61511 SIS Expert designation.
- **ISA/IEC 62443**: Fundamentals, Risk Assessment, Design and Maintenance Specialist
  certificates, leading to ISA/IEC 62443 Cybersecurity Expert.

### D.6.4 Functional safety

- **TÜV Rheinland Functional Safety Program.** Courses from TÜV Rheinland and accepted
  course providers (including some automation vendors) end in an exam. Candidates who also
  meet the experience and education requirements receive the **FS Engineer (TÜV
  Rheinland)** certificate for an application area, such as safety instrumented systems,
  machinery, or hardware/software design to IEC 61508. There is also an **FS Technician**
  certificate, aimed at technicians, mechanics and programmers.
- **TÜV SÜD** runs its own **Functional Safety Certification Programme (FSCP)**, with exams
  at several levels (engineer, professional and expert) and versions for different standards,
  including IEC 61508 and ISO 26262 (automotive). Check each course's scope.
- **CFSE / CFSP** (Certified Functional Safety Expert / Professional): a programme started
  by exida in 2000 and still associated with it. CFSP suits people who carry out safety
  lifecycle work, CFSE those who lead and review it.

The engineer- and expert-level certificates ask for years of relevant experience. If your
job already involves cause-and-effect matrices, SRS reviews or proof-test procedures, you
are building it now. Keep a record.

### D.6.5 Hazardous areas: CompEx

**CompEx** is the UK-originated competence scheme for work in explosive atmospheres,
developed by EEMUA and JTL with HSE support, and now run by CompEx Certification, part of the
JTL Group. The core is **Ex01–Ex04 (gas and vapours)** for electrical and instrument
technicians who install, inspect and maintain Ex equipment, assessed by practical tasks and an
online exam. Other units cover dust (Ex05–Ex06), mechanical work (Ex11), application design
(Ex12) and responsible persons (Ex14). Certificates must be renewed (every five years at the
time of writing). Many oil, gas and chemical sites require CompEx for work on Ex equipment. A
programmer who never touches field equipment may not need it, but if you design or check IS
loops and barriers ([Module 02](../02-electrical-and-field-devices/)), the design unit or an
equivalent course is valuable. Internationally, **IECEx** offers a Certificate of Personnel
Competence (CoPC).

### D.6.6 UK electrical: ECS cards and the 18th Edition

- The **ECS (Electrotechnical Certification Scheme)** card, owned by the **JIB** (Joint
  Industry Board for the electrical contracting industry), is the electrotechnical industry's
  identity and competence card. The card type follows your qualifications, for example a Gold
  card for qualified electricians. Most applicants must also pass the ECS Health, Safety and
  Environmental assessment. Many installation and construction sites ask for one.
- The **18th Edition** qualification (City & Guilds 2382, with equivalents from other
  awarding bodies) tests knowledge of BS 7671. Its version number follows the current
  amendment, and many employers expect holders to update after a major amendment. It is a
  knowledge qualification, not a qualification to work as an electrician.

These matter if your role includes panel building, installation or electrical maintenance.
For an office-based design or programming role they are useful background, not essential.

### D.6.7 Professional registration (UK)

The **Engineering Council** sets the UK standard for professional engineers and technicians
(UK-SPEC) and licenses professional bodies to assess candidates:

| Title | In short |
|---|---|
| **EngTech** (Engineering Technician) | Applies proven techniques and procedures to practical engineering problems. A realistic first target for an experienced technician or documentation specialist |
| **IEng** (Incorporated Engineer) | Manages the application of current technology; may design, develop and commission |
| **CEng** (Chartered Engineer) | Solves complex problems, leads technical work and takes responsibility for it |

The natural bodies for control and instrumentation are **InstMC** (Institute of Measurement
and Control), the specialist body, and the **IET** (Institution of Engineering and
Technology), which also publishes BS 7671. Both are licensed for EngTech, IEng and CEng. If
you move towards process safety, **IChemE** is the other body to know. Registration is based
on demonstrated competence, and experience-based routes exist for people without the standard
academic qualifications. Start a competence log now: projects, what you did personally, the
standards you applied and the decisions you made. That log becomes your application.

### D.6.8 Career paths

| Role | Typical work | Useful next steps |
|---|---|---|
| **E&I / maintenance technician** | Fault-finding, loop checks, small logic changes under permit | CompEx on Ex sites, ECS card, ISA CCST, EngTech |
| **Controls / automation engineer** (integrator or machine builder) | Writing and commissioning PLC, HMI and drive software | Vendor certification, machinery functional safety, IEng/CEng |
| **Instrument and control engineer** (process) | Instrument specifications, loop drawings, control narratives, DCS/PLC configuration, MOC | InstMC, IEng/CEng, IEC 61511 training |
| **SIS / functional safety engineer** | HAZOP and LOPA support, SRS, SIL verification, C&E matrices, proof tests | TÜV or CFSE certification, ISA/IEC 61511 certificates |
| **Commissioning engineer** | FAT, SAT, loop checks and start-up, often travelling | CompEx, ECS, platform skills |
| **OT cyber security specialist** | Zoning, access control, patching strategy, IEC 62443 assessments | ISA/IEC 62443 certificates, networking |

**If you already work with process-safety and instrumentation documents**, you read loop
drawings, IS barrier schedules and cause-and-effect matrices, which many new programmers
cannot. Build on that: finish the capstones, take your site's main platform to a professional
level, aim for a functional safety certificate once you have the experience, and start an
InstMC or IET competence log towards EngTech or IEng. People who can connect the SRS, the C&E
matrix and the logic that implements them are in short supply.

## D.7 Building a portfolio

### D.7.1 What to show

An interviewer wants evidence that you can turn a specification into working, tested,
maintainable logic. The capstones in [Module 24](../24-capstone-projects/) are designed for
exactly that:

- [24-1 Conveyor sorting cell](../24-capstone-projects/24-1-conveyor-sorting-cell.md):
  machine control, part tracking, pushers, jams and a stack light.
- [24-2 Batch mixing plant](../24-capstone-projects/24-2-batch-mixing-plant.md): recipes,
  flow-meter dosing, PID heating and an ISA-88-style procedure with hold, restart and abort.
- [24-3 Wastewater pump station](../24-capstone-projects/24-3-pump-station.md): a 4–20 mA
  level with NE 43 fault limits, duty/assist/standby pumps, alarms and a SCADA register map.

Each has a functional specification and an acceptance test (FAT), so you can show a passing
test run, not just code. One capstone done thoroughly and written up well beats three rushed.

### D.7.2 Git and the write-up

Give each project its own repository ([Module 22](../22-software-engineering/)):

```text
pump-station/
├── README.md       the write-up
├── src/            .st files, or the exported vendor project
├── test/           the acceptance test plus tests you added
├── docs/           state diagram, I/O list, alarm list, cause-and-effect matrix
└── evidence/       plctest output, screenshots, a short screen recording
```

Commit in small steps with clear messages ("Add dry-run protection to FB_Pump", not
"changes"): the history shows how you work. Tag the version that passes the full FAT. The
README should cover, in a page or two:

1. What the system does, in terms a plant manager would understand.
2. Your design: program structure (with a diagram), main function blocks, state machine, and
   how alarms and interlocks work.
3. The decisions you made and why, for example how the stop logic fails safe on a broken wire.
4. How you tested it: the FAT result, your extra tests, and the bugs they caught.
5. What a real plant would need that the exercise leaves out.
6. A clear statement that it is a training project, and that any safety-related logic is an
   exercise, not a design for a real safety function.

**Never publish** an employer's or client's code, drawings, specifications, tag lists,
network details or plant photos. Even "anonymised" material often identifies a site, and it
is almost certainly covered by your contract. Build portfolio projects from scratch.

### D.7.3 A practice bench (optional)

You can learn everything here without hardware, but wiring a real input and watching the LED
change makes Modules 02, 14 and 23 concrete. A generic shopping list:

| Item | Notes |
|---|---|
| **24 V DC power supply** | The safest choice is an enclosed supply with a moulded mains lead, like a laptop power brick, so you never touch a mains terminal. If you use a DIN-rail supply, have a competent person wire, fuse, earth and enclose its mains side. Size it for your total load with a margin |
| **Controller** | Either a small second-hand PLC with free or trial software (an S7-1200, Micro820/850, CLICK or a CODESYS-based controller), choosing a **DC-powered** model with 24 V DC inputs; or a Raspberry Pi running OpenPLC or a CODESYS runtime **with a proper isolated 24 V I/O board** |
| **Push-buttons and a selector switch** | Green start (NO), red stop (NC). 22 mm types with separate contact blocks let you practise NO and NC wiring |
| **Emergency-stop button** | For practising wiring and logic only. On a bench it is not a safety function (Module 20) |
| **Pilot lights** | 24 V DC LED types in a few colours |
| **Interface relays** | Two or three with 24 V DC coils and built-in suppression |
| **Sensors** | A 3-wire PNP inductive proximity sensor (to suit a sinking PLC input) and perhaps a photo-eye |
| **An analog signal** | A loop calibrator or simple 4–20 mA source, or a potentiometer on a 0–10 V input. A 250 Ω resistor turns 4–20 mA into 1–5 V for a voltage-only input, just as on your loop drawings |
| **Mounting and wiring** | A board with DIN rail, terminal blocks, fuse terminals, flexible wire in a few colours, ferrules and a crimper, wire markers. Draw it first and tag it (IEC 81346 practice) |
| **Multimeter** | A decent one, with a category rating suitable for industrial panels if you will also use it at work |

Four bench rules:

1. **Never connect 24 V to a Raspberry Pi's GPIO pins.** They are 3.3 V logic and will be
   destroyed. Use an isolated I/O board designed for 24 V signals.
2. **Mains wiring is for qualified people only.** Keep the bench at 24 V DC.
3. **Buy second-hand PLCs from reputable sellers.** Counterfeit and grey-market automation
   hardware exists. Check that your software supports the CPU and firmware, and that the
   seller can clear any password protection.
4. **The bench is a test rig.** Nothing on it is ever connected to plant.

---

Back to the course home: **[PLC Programming Course](../README.md)** ·
Start of the course: **[00 — Start Here](../00-start-here/)**

Other appendices: [A — Vendor cross-reference](A-vendor-cross-reference.md) ·
[B — Glossary](B-glossary.md) ·
[C — Study plan and self-assessment](C-study-plan-and-self-assessment.md) ·
[E — MATIEC and OpenPLC notes](E-matiec-openplc-notes.md)
