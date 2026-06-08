import os
import sys
import requests
from http.server import BaseHTTPRequestHandler, HTTPServer
from werkzeug.formparser import parse_form_data


class TranslateHandler(BaseHTTPRequestHandler):

    def do_POST(self):
        environ = {
            "CONTENT_TYPE": self.headers.get("Content-Type", ""),
            "CONTENT_LENGTH": self.headers.get("Content-Length", "0"),
            "wsgi.input": self.rfile,
        }
        _, form_data, _ = parse_form_data(environ)

        token = form_data.get("token", "").strip()
        channel = form_data.get("channel", "").strip()
        text = form_data.get("text", "").strip()

        print("--- DEBUG: Incoming Request Parsed ---", file=sys.stderr)
        print(f"Token found: {'Yes' if token else 'No'}", file=sys.stderr)
        print(f"Channel: '{channel}'", file=sys.stderr)
        print(f"Text Payload: '{text}'", file=sys.stderr)
        print("---", file=sys.stderr)
        sys.stderr.flush()

        if not token:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Error: Token parameter missing")
            return

        mm_payload = {
            "text": text or "Empty message body received from device.",
            "channel": channel,
        }

        target_port = os.environ.get("MATTERMOST_PORT", "8065")
        target_url = f"http://127.0.0.1:{target_port}/hooks/{token}"

        try:
            response = requests.post(
                target_url,
                json=mm_payload,
                timeout=10,
                headers={"User-Agent": "Mattermost-Slack-Translator"}
            )

            self.send_response(response.status_code)
            self.send_header("Content-Type",
                             response.headers.get("Content-Type",
                                                  "text/plain"))
            self.end_headers()
            self.wfile.write(response.content)

        except requests.exceptions.RequestException as e:
            print(f"Proxy Connection Error: {e}", file=sys.stderr)
            self.send_response(502)
            self.end_headers()
            self.wfile.write(b"Bad Gateway: Could not reach Mattermost.")


if __name__ == "__main__":
    print("Starting local translation layer...")
    translator_port = int(os.environ.get("TRANSLATOR_PORT", 8066))
    HTTPServer(("127.0.0.1", translator_port),
               TranslateHandler).serve_forever()
