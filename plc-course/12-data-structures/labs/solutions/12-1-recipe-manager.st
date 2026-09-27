(* Lab 12-1: Recipe manager - an array of structures, validated before use.
   Module 12 (Data structures). REFERENCE SOLUTION - try the lab yourself first.

   A jacketed mixing vessel makes five products. Each product's recipe is a
   structure (name, three ingredient doses, temperature, mixing time), and the
   recipe book is an ARRAY[1..5] OF ST_Recipe that the operator edits on the
   HMI. The batch sequence never uses the book directly: it uses Active, a
   validated copy taken when the operator presses Load.

   Design points shown here:
   - the index from the HMI is checked BEFORE Recipes[SelectNo] is touched;
   - the value checks live in a FUNCTION that takes the recipe and the limits
     as structures, so the same check serves the live "Load" button status and
     the load itself;
   - the load is all-or-nothing: one whole-structure assignment, only after
     every check has passed. A rejected load leaves Active exactly as it was. *)

TYPE
  ST_Recipe :
  STRUCT
    Name    : STRING;               (* product name shown on the HMI; '' = empty slot *)
    Dose    : ARRAY[1..3] OF REAL;  (* kg of ingredient 1 (water), 2 (base), 3 (seasoning) *)
    Temp    : REAL;                 (* degC, batch temperature setpoint *)
    MixTime : TIME;                 (* mixing time once the batch is at temperature *)
  END_STRUCT;

  ST_RecipeLimits :
  STRUCT
    DoseMax    : REAL;              (* kg, largest dose of any one ingredient *)
    TotalMax   : REAL;              (* kg, vessel working capacity *)
    TempMin    : REAL;              (* degC *)
    TempMax    : REAL;              (* degC *)
    MixTimeMin : TIME;
    MixTimeMax : TIME;
  END_STRUCT;

  (* Result of the last load command. The first value is the initial value. *)
  E_LoadResult : (NotLoaded, Loaded, BadIndex, EmptySlot, BadValue, BatchBusy);
END_TYPE


FUNCTION F_RecipeValuesOk : BOOL
  (* TRUE when every number in the recipe is inside its limits (all limits
     inclusive). The name is the caller's business. Guard-clause style: the
     result starts FALSE and each failed check leaves at once with RETURN. *)
  VAR_INPUT
    R   : ST_Recipe;          (* the recipe to check (passed by value: a copy) *)
    Lim : ST_RecipeLimits;    (* the limits, also a structure *)
  END_VAR
  VAR
    i     : INT;
    Total : REAL;             (* kg, sum of the three doses *)
  END_VAR

  F_RecipeValuesOk := FALSE;              (* guilty until proven innocent *)

  Total := 0.0;
  FOR i := 1 TO 3 DO
    IF R.Dose[i] < 0.0 OR R.Dose[i] > Lim.DoseMax THEN
      RETURN;                             (* one bad dose rejects the recipe *)
    END_IF;
    Total := Total + R.Dose[i];
  END_FOR;

  (* A cross-check that no single field can make: three legal doses can
     still overfill the vessel. An all-zero recipe is meaningless too. *)
  IF Total <= 0.0 OR Total > Lim.TotalMax THEN
    RETURN;
  END_IF;

  IF R.Temp < Lim.TempMin OR R.Temp > Lim.TempMax THEN
    RETURN;
  END_IF;

  IF R.MixTime < Lim.MixTimeMin OR R.MixTime > Lim.MixTimeMax THEN
    RETURN;
  END_IF;

  F_RecipeValuesOk := TRUE;
END_FUNCTION


PROGRAM RecipeManager
  VAR (* recipe book, edited on the HMI recipe screen. Slots 1 to 4 are
         filled in by the first-scan block at the top of the code. Slot 4
         holds a typing mistake (95 degC), and slot 5 is left empty on
         purpose ('', 0.0 and T#0s). Both must be refused. *)
    Recipes : ARRAY[1..5] OF ST_Recipe;
  END_VAR
  VAR (* HMI selection and command, and the state of the batch *)
    SelectNo     : INT;             (* recipe number chosen on the HMI; 0 = none *)
    LoadCmd      : BOOL;            (* HMI sets it to request a load; the PLC clears it *)
    BatchRunning : BOOL;            (* TRUE while a batch is in progress (from the sequence) *)
  END_VAR
  VAR (* results - keep these names *)
    SelectedOk   : BOOL;            (* the selected recipe could be loaded (enables the Load button) *)
    Active       : ST_Recipe;       (* the recipe the batch sequence uses *)
    ActiveNo     : INT;             (* which slot Active came from; 0 = nothing loaded yet *)
    LoadResult   : E_LoadResult;    (* outcome of the last load command *)
  END_VAR
  VAR (* the limits of this vessel: set by the first-scan block, never written anywhere else *)
    RecipeLimits : ST_RecipeLimits;
  END_VAR
  VAR CONSTANT
    FIRST_SLOT : INT := 1;          (* keep in step with the ARRAY[1..5] bounds *)
    LAST_SLOT  : INT := 5;
  END_VAR
  VAR
    Initialised : BOOL;             (* NOT retentive: FALSE until the first-scan block has run *)
    Check : E_LoadResult;           (* what a load of the selected slot would give now *)
  END_VAR

  (* ---- 0. First scan only: fill in the recipe book and the limits.
     Standard IEC 61131-3 would give both as initialisers in the declarations:
       Recipes : ARRAY[1..5] OF ST_Recipe := [
         (Name := 'Tomato soup', Dose := [400.0, 150.0, 20.0], Temp := 85.0, MixTime := T#20m),
         ...];
       RECIPE_LIMITS : ST_RecipeLimits := (DoseMax := 500.0, ...);   (a VAR CONSTANT)
     OpenPLC's compiler does not accept these initialisers (see Appendix E),
     so the values are set here. The block is at the very top, so the values
     are in place before anything below reads them, from the first scan on.
     Initialised is not RETAIN, so every restart starts again from these
     values, as the initialisers would. (If the book were RETAIN, as it would
     be on a real plant, Initialised would have to be RETAIN too, or every
     warm restart would overwrite the operator's edits.) ---- *)
  IF NOT Initialised THEN
    Recipes[1].Name := 'Tomato soup';
    Recipes[1].Dose[1] := 400.0;  Recipes[1].Dose[2] := 150.0;  Recipes[1].Dose[3] := 20.0;
    Recipes[1].Temp := 85.0;      Recipes[1].MixTime := T#20m;

    Recipes[2].Name := 'Vegetable stock';
    Recipes[2].Dose[1] := 450.0;  Recipes[2].Dose[2] := 300.0;  Recipes[2].Dose[3] := 10.0;
    Recipes[2].Temp := 80.0;      Recipes[2].MixTime := T#30m;

    Recipes[3].Name := 'Cheese sauce';
    Recipes[3].Dose[1] := 250.0;  Recipes[3].Dose[2] := 200.0;  Recipes[3].Dose[3] := 50.0;
    Recipes[3].Temp := 65.0;      Recipes[3].MixTime := T#15m;

    Recipes[4].Name := 'Trial batch';
    Recipes[4].Dose[1] := 100.0;  Recipes[4].Dose[2] := 100.0;  Recipes[4].Dose[3] := 0.0;
    Recipes[4].Temp := 95.0;      Recipes[4].MixTime := T#10m;   (* 95 degC: the typing mistake *)

    (* slot 5 is left empty *)

    RecipeLimits.DoseMax    := 500.0;     (* kg, largest dose of any one ingredient *)
    RecipeLimits.TotalMax   := 1000.0;    (* kg, vessel working capacity *)
    RecipeLimits.TempMin    := 20.0;      (* degC *)
    RecipeLimits.TempMax    := 85.0;      (* degC *)
    RecipeLimits.MixTimeMin := T#1m;
    RecipeLimits.MixTimeMax := T#2h;

    Initialised := TRUE;
  END_IF;

  (* ---- 1. Check the selected slot, every scan. The index comes from the
     HMI, so it is tested FIRST: Recipes[SelectNo] is only read inside the
     ELSIF branches, which run only when the index is in range. ---- *)
  IF SelectNo < FIRST_SLOT OR SelectNo > LAST_SLOT THEN
    Check := BadIndex;
  ELSIF LEN(Recipes[SelectNo].Name) = 0 THEN
    Check := EmptySlot;
  ELSIF NOT F_RecipeValuesOk(R := Recipes[SelectNo], Lim := RecipeLimits) THEN
    Check := BadValue;
  ELSE
    Check := Loaded;   (* passes every check: it can be loaded *)
  END_IF;

  SelectedOk := Check = Loaded;

  (* ---- 2. The load command: acted on once, then cleared (the HMI sets
     command bits, the PLC clears them). Never change the recipe of a batch
     that is running. ---- *)
  IF LoadCmd THEN
    IF BatchRunning THEN
      LoadResult := BatchBusy;
    ELSE
      LoadResult := Check;
      IF Check = Loaded THEN
        Active := Recipes[SelectNo];      (* whole-structure copy: all or nothing *)
        ActiveNo := SelectNo;
      END_IF;
    END_IF;
    LoadCmd := FALSE;
  END_IF;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : RecipeManager;
  END_RESOURCE
END_CONFIGURATION
