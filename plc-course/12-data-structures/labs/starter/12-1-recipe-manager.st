(* Lab 12-1: Recipe manager - an array of structures, validated before use.
   Module 12 (Data structures). STARTER - the types, the recipe book, the
   limits and the program interface are declared for you. The recipe book
   and the limits are filled in by the first-scan block at the top of the
   program body: keep it there, above your own code. Write:
     1. the live check of the selected slot (SelectedOk),
     2. the load command: validate, then copy the whole recipe into Active,
        or reject it with the right LoadResult and change nothing.
   A FUNCTION for the value checks is a good idea (see the hint in the README).
   Then run:
     python3 tools/plctest.py 12-data-structures/labs/starter/12-1-recipe-manager.st *)

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
    (* TODO: add your internal variables here. *)
  END_VAR

  (* ---- First scan only (given): fill in the recipe book and the limits.
     Standard IEC 61131-3 would give both as initialisers in the declarations:
       Recipes : ARRAY[1..5] OF ST_Recipe := [
         (Name := 'Tomato soup', Dose := [400.0, 150.0, 20.0], Temp := 85.0, MixTime := T#20m),
         ...];
       RECIPE_LIMITS : ST_RecipeLimits := (DoseMax := 500.0, ...);   (a VAR CONSTANT)
     OpenPLC's compiler does not accept these initialisers (see Appendix E),
     so the values are set here. Keep this block at the very top, so the
     values are in place before your code reads them, from the first scan
     on. ---- *)
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

  (* TODO: replace these placeholder lines with the recipe manager logic.
     Test the index BEFORE you read Recipes[SelectNo]. *)
  SelectedOk := FALSE;
  LoadCmd := FALSE;
END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK MainTask(INTERVAL := T#10ms, PRIORITY := 0);
    PROGRAM Inst0 WITH MainTask : RecipeManager;
  END_RESOURCE
END_CONFIGURATION
