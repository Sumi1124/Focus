"""Local Ollama contract fixture for the macOS integration checks."""
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class OllamaFixture(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def send_json(self, value, status=200):
        data = json.dumps(value).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        if self.path == '/api/tags':
            self.send_json({'models': [
                {'name': 'test-model'},
                {'name': 'hosted-model:latest-cloud', 'remote_host': 'https://ollama.com', 'remote_model': 'hosted-model'},
            ]})
        else:
            self.send_json({'error': 'unknown endpoint'}, 404)

    def do_POST(self):
        if self.path != '/api/chat':
            self.send_json({'error': 'unknown endpoint'}, 404)
            return
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        messages = body['messages']
        if body['model'] != 'test-model' or 'Photosynthesis uses light to make sugars.' not in messages[0]['content']:
            self.send_json({'error': 'missing selected model or source context'}, 400)
            return
        prompt = messages[-1]['content']
        if prompt == 'return_error':
            self.send_json({'error': 'simulated failure'}, 500)
            return
        if prompt == 'slow_request':
            time.sleep(10)
        if 'flashcards' in prompt:
            answer = json.dumps({'cards': [{'front': 'What powers photosynthesis?', 'back': 'Light.', 'citations': ['S1', 'S99']}]})
        elif 'multiple-choice' in prompt:
            answer = json.dumps({'questions': [{'question': 'What powers photosynthesis?', 'options': ['Light', 'Sound'], 'answerIndex': 0, 'explanation': 'The source says light.', 'citations': ['S1']}]})
        else:
            answer = 'Photosynthesis uses light to make sugars [S1]. Invented reference [S99].'
        self.send_json({'message': {'role': 'assistant', 'content': answer}})


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 11434), OllamaFixture).serve_forever()
