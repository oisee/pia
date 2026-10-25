#!/usr/bin/env python3
"""Loopback-only scripted OpenAI chat server; never calls a model."""
import argparse
import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--port', type=int, default=8089)
parser.add_argument('--delay', type=float, default=150)
parser.add_argument('--tests-only', action='store_true', help='Test the demo after the previous turn publishes')
args = parser.parse_args()
source = next((Path(__file__).resolve().parents[2] / 'src').rglob('zcl_pia_demo.clas.abap')).read_text()
steps = [
    ('read_object', {'name': 'ZCL_PIA_DEMO'}),
    ('write_source', {'name': 'ZCL_PIA_DEMO', 'source': source}),
    ('activate', {'name': 'ZCL_PIA_DEMO'}),
    ('run_tests', {'name': 'ZCL_PIA_DEMO'}),
]
if args.tests_only:
    steps = [('run_tests', {'name': 'ZCL_PIA_DEMO'})]
lock = threading.Lock()
position = 0


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        global position
        try:
            request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            assert self.path == '/v1/chat/completions', 'unexpected endpoint'
            assert 'Authorization' not in self.headers, 'expected no authentication'
            assert request['temperature'] == 0.2 and request['max_tokens'] == 512
            for message in request['messages']:
                for call in message.get('tool_calls', []):
                    assert call['type'] == 'function'
                    assert isinstance(call['function']['arguments'], str)
                    json.loads(call['function']['arguments'])
            with lock:
                index = position
                position += 1
            if index < len(steps):
                name, arguments = steps[index]
                message = {'role': 'assistant', 'content': None if index == 0 else '',
                           'tool_calls': [{'id': f'c{index}', 'type': 'function',
                                           'function': {'name': name, 'arguments': json.dumps(arguments)}}]}
                if index == 0:
                    message['reasoning_content'] = 'This field must be ignored.'
                reason = 'tool_calls'
                print(f'step {index}: {name}', flush=True)
            else:
                if index == len(steps):
                    print(f'delay start: {args.delay}s', flush=True)
                    time.sleep(args.delay)
                message = {'role': 'assistant', 'content': 'Local scripted turn complete.'}
                reason = 'stop'
            body = json.dumps({'choices': [{'index': 0, 'message': message, 'finish_reason': reason}]}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            print(f'response {index}: sent', flush=True)
        except (AssertionError, ValueError, KeyError) as error:
            print(f'invalid request: {error}', flush=True)
            self.send_error(400, 'Invalid scripted request')
        except (BrokenPipeError, ConnectionResetError):
            print('client disconnected before response', flush=True)


ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
