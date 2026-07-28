module modules.project_recognizer.recognizer;

/// Compatibility shim: DevCentr consumes openshellorg/project-map.
public import project_map.recognizer;
public import project_map.types;

/// Historical name used by DevCentr UI / workspace manager.
alias ArchitectureModel = ProjectScan;

/// Historical options name; maps onto project-map ViewOptions.
alias RecognizerOptions = ViewOptions;
