{
  sourceInfo,
  componentLib,
  core,
  web,
  nativeEngine,
  graphJson,
}:
componentLib.mkMetaPackage {
  pname = "gsd-2";
  version = sourceInfo.version;
  paths = [
    core
    web
    nativeEngine
  ];
  summary = "Primary external gsd-2 meta package intended to hide the internal split build graph.";
  mainProgram = "gsd";
  details = [
    "Combines the default CLI runtime, packaged web lane, and native engine lane."
    "Is the package external consumers should normally reference."
    "Intentionally leaves companions and optional runtime helpers outside the default closure."
  ];
  files = {
    "graph.json" = graphJson;
    "meta-layout.txt" = ''
      default meta package:
      - gsd-2-core
      - gsd-2-web
      - gsd-2-native-engine
    '';
  };
}
