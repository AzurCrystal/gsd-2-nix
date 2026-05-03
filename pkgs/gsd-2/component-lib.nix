{
  lib,
  stdenvNoCC,
  symlinkJoin,
}:
let
  renderList =
    items: if items == [ ] then "- none" else lib.concatMapStringsSep "\n" (item: "- ${item}") items;

  renderFiles =
    files:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: text: ''
                  mkdir -p "$out/share/gsd-2-blueprint"
                  cat <<'EOF' > "$out/share/gsd-2-blueprint/${name}"
        ${text}
        EOF
      '') files
    );

  renderBins =
    shell: bins:
    lib.concatStringsSep "\n" (
      map (bin: ''
                  mkdir -p "$out/bin"
                  cat <<'EOF' > "$out/bin/${bin.name}"
        #!${shell}
        set -euo pipefail
        ${bin.text}
        EOF
                  chmod +x "$out/bin/${bin.name}"
      '') bins
    );
in
{
  mkDocComponent =
    {
      pname,
      version,
      role,
      summary,
      details ? [ ],
      bins ? [ ],
      files ? { },
      mainProgram ? null,
    }:
    stdenvNoCC.mkDerivation {
      inherit pname version;
      dontUnpack = true;

      installPhase = ''
                mkdir -p "$out/share/gsd-2-blueprint/components"

                cat <<'EOF' > "$out/share/gsd-2-blueprint/components/${pname}.md"
        # ${pname}

        role: ${role}
        summary: ${summary}

        details:
        ${renderList details}
        EOF

        ${renderFiles files}
        ${renderBins stdenvNoCC.shell bins}

                rmdir "$out/bin" 2>/dev/null || true
      '';

      meta = {
        description = summary;
        platforms = lib.platforms.unix;
      }
      // lib.optionalAttrs (mainProgram != null) {
        inherit mainProgram;
      };
    };

  mkMetaPackage =
    {
      pname,
      version,
      summary,
      details ? [ ],
      paths,
      files ? { },
      mainProgram ? null,
    }:
    symlinkJoin {
      name = "${pname}-${version}";
      inherit paths;

      postBuild = ''
                mkdir -p "$out/share/gsd-2-blueprint"

                cat <<'EOF' > "$out/share/gsd-2-blueprint/${pname}.md"
        # ${pname}

        summary: ${summary}

        details:
        ${renderList details}
        EOF

        ${renderFiles files}
      '';

      meta = {
        description = summary;
        platforms = lib.platforms.unix;
      }
      // lib.optionalAttrs (mainProgram != null) {
        inherit mainProgram;
      };
    };
}
