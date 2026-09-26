(* Lab 12-1: Recipe manager - an array of structures, validated before use.
   Module 12 (Data structures). STARTER - the types, the recipe book, the
   limits and the program interface are declared for you. Write:
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
  VAR (* recipe book, edited on the HMI recipe screen. Slot 4 holds a typing
         mistake (95 degC), and slot 5 is empty (it is left out of the
         initialiser on purpose, so it starts as '', 0.0 and T#0s). Both
         must be refused. *)
    Recipes : ARRAY[1..5] OF ST_Recipe := [
      (Name := 'Tomato soup',     Dose := [400.0, 150.0, 20.0], Temp := 85.0, MixTime := T#20m),
      (Name := 'Vegetable stock', Dose := [450.0, 300.0, 10.0], Temp := 80.0, MixTime := T#30m),
      (Name := 'Cheese sauce',    Dose := [250.0, 200.0, 50.0], Temp := 65.0, MixTime := T#15m),
      (Name := 'Trial batch',     Dose := [100.0, 100.0, 0.0],  Temp := 95.0, MixTime := T#10m)];
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
  VAR CONSTANT
    RECIPE_LIMITS : ST_RecipeLimits := (DoseMax := 500.0, TotalMax := 1000.0,
                                        TempMin := 20.0, TempMax := 85.0,
                                        MixTimeMin := T#1m, MixTimeMax := T#2h);
    FIRST_SLOT : INT := 1;          (* keep in step with the ARRAY[1..5] bounds *)
    LAST_SLOT  : INT := 5;
  END_VAR
  (* TODO: add a VAR ... END_VAR block here for your internal variables. *)

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
