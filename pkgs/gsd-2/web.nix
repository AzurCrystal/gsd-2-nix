{
  pkgs,
  sourceInfo,
  builtTree,
  webModules,
  nativeEngine,
}:
pkgs.stdenvNoCC.mkDerivation {
  pname = "gsd-2-web";
  inherit (sourceInfo) version;

  src = builtTree;
  nativeBuildInputs = [ pkgs.nodejs_24 ];
  env = sourceInfo.commonEnv;

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR"

    cp -a ${webModules}/node_modules ./web/node_modules

    cat > web/app/layout.tsx <<'EOF'
    import type { Metadata, Viewport } from 'next'
    import { Toaster } from '@/components/ui/sonner'
    import { ThemeProvider } from '@/components/theme-provider'
    import './globals.css'

    export const metadata: Metadata = {
      title: 'GSD',
      description: 'The evolution of Get Shit Done — now a real coding agent. One command. Walk away. Come back to a built project.',
      applicationName: 'GSD',
      icons: {
        icon: [
          {
            url: '/icon-light-32x32.png',
            media: '(prefers-color-scheme: light)',
          },
          {
            url: '/icon-dark-32x32.png',
            media: '(prefers-color-scheme: dark)',
          },
          {
            url: '/icon.svg',
            type: 'image/svg+xml',
          },
        ],
      },
    }

    export const viewport: Viewport = {
      width: 'device-width',
      initialScale: 1,
      maximumScale: 1,
      userScalable: false,
    }

    export default function RootLayout({
      children,
    }: Readonly<{
      children: React.ReactNode
    }>) {
      return (
        <html lang="en" suppressHydrationWarning>
          <body className="font-sans antialiased">
            <ThemeProvider attribute="class" defaultTheme="dark">
              {children}
              <Toaster position="bottom-right" />
            </ThemeProvider>
          </body>
        </html>
      )
    }
    EOF

    substituteInPlace web/app/globals.css \
      --replace "--font-sans: var(--font-geist-sans), 'Geist', 'Geist Fallback';" "--font-sans: 'Noto Sans', 'Segoe UI', sans-serif;" \
      --replace "--font-mono: var(--font-geist-mono), 'Geist Mono', 'Geist Mono Fallback';" "--font-mono: 'JetBrains Mono', 'Consolas', monospace;"

    substituteInPlace web/styles/globals.css \
      --replace "--font-sans: 'Geist', 'Geist Fallback';" "--font-sans: 'Noto Sans', 'Segoe UI', sans-serif;" \
      --replace "--font-mono: 'Geist Mono', 'Geist Mono Fallback';" "--font-mono: 'JetBrains Mono', 'Consolas', monospace;"

    npm --prefix web run build
    npm run stage:web-host

    nativeLink="dist/web/standalone/node_modules/@gsd/native"
    if [ -L "$nativeLink" ]; then
      rm "$nativeLink"
      ln -s ../../../../../packages/native "$nativeLink"
    fi

    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall

        mkdir -p "$out/dist" "$out/packages" "$out/native" "$out/share/gsd-2-blueprint/components"
        cp -a dist/web "$out/dist/"
        cp -a packages/native "$out/packages/"
        ln -s ${nativeEngine}/lib/node_modules/gsd-pi/native/addon "$out/native/addon"

        cat <<'EOF' > "$out/share/gsd-2-blueprint/components/gsd-2-web.md"
    # gsd-2-web

    role: packaged standalone web host
    summary: Real phase-2 packaged standalone web-host lane intended to populate dist/web/standalone in the final meta package.

    details:
    - consumes the shared built tree instead of pretending web is a fully isolated frontend
    - patches Next font fetching to a local offline layout during the build
    - stages the standalone host and rewrites the @gsd/native symlink to the final package-relative target
    - exposes the source-built native addon at the standalone host's expected relative path
    EOF

        runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Packaged standalone web host for gsd-2";
    homepage = "https://github.com/gsd-build/gsd-2";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
