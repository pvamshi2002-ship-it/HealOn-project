"""Read-only API smoke probe — no writes except auth POST (session token)."""
import json
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = 'http://127.0.0.1:8000'


def request(method, path, data=None, token=None):
    headers = {}
    if token:
        headers['Authorization'] = f'Token {token}'
    body = urllib.parse.urlencode(data).encode() if data else None
    req = urllib.request.Request(BASE + path, data=body, headers=headers, method=method)
    start = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            elapsed = (time.perf_counter() - start) * 1000
            raw = resp.read().decode()
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                payload = raw[:120]
            return resp.status, elapsed, payload
    except urllib.error.HTTPError as exc:
        elapsed = (time.perf_counter() - start) * 1000
        raw = exc.read().decode()
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            payload = raw[:120]
        return exc.code, elapsed, payload


def main():
    results = []
    tokens = {}

    for role, username, password in [
        ('Admin', 'admin', 'Admin@123'),
        ('User', 'employee', 'Employee@123'),
        ('HR', 'hr', 'HR@123'),
    ]:
        status, ms, body = request(
            'POST',
            '/api/auth/',
            {'username': username, 'password': password, 'role': role},
        )
        ok = status == 200 and isinstance(body, dict) and body.get('token')
        results.append(('Auth ' + role, 'PASS' if ok else 'FAIL', status, f'{ms:.0f}ms'))
        if ok:
            tokens[role] = body['token']

    # Role mismatch (should be rejected)
    status, ms, body = request(
        'POST',
        '/api/auth/',
        {'username': 'employee', 'password': 'Employee@123', 'role': 'Admin'},
    )
    results.append(
        (
            'Auth role mismatch (employee as Admin)',
            'PASS' if status == 403 else 'FAIL',
            status,
            f'{ms:.0f}ms',
        )
    )

    user_token = tokens.get('User')
    admin_token = tokens.get('Admin')
    hr_token = tokens.get('HR')

    read_only_gets = [
        ('User /me/', '/api/me/', user_token),
        ('User dashboard', '/api/dashboard/', user_token),
        ('User attendance report', '/api/attendance-report/?month=2026-06', user_token),
        ('User tasks', '/api/employee/tasks/', user_token),
        ('User leaves', '/api/employee/leaves/', user_token),
        ('User salary', '/api/employee/salary/', user_token),
        ('User reimbursements', '/api/employee/reimbursements/', user_token),
        ('User helpdesk', '/api/employee/helpdesk/', user_token),
        ('User directory', '/api/employee/directory/', user_token),
        ('Admin dashboard', '/api/admin/dashboard/', admin_token),
        ('Admin stats', '/api/admin/stats/', admin_token),
        ('Admin employees', '/api/admin/employees/', admin_token),
        ('Admin attendance', '/api/admin/attendance/', admin_token),
        ('Admin attendance settings', '/api/admin/attendance-settings/', admin_token),
        ('Admin salary records', '/api/admin/salary-records/', admin_token),
        ('Admin reimbursements', '/api/admin/reimbursements/', admin_token),
        ('Admin tasks', '/api/admin/tasks/', admin_token),
        ('HR admin dashboard', '/api/admin/dashboard/', hr_token),
        ('HR employees list', '/api/admin/employees/', hr_token),
    ]

    for name, path, token in read_only_gets:
        status, ms, _ = request('GET', path, token=token)
        results.append((name, 'PASS' if status == 200 else 'FAIL', status, f'{ms:.0f}ms'))

    status, ms, _ = request('GET', '/api/admin/dashboard/', token=user_token)
    results.append(
        (
            'RBAC: employee blocked from admin dashboard',
            'PASS' if status == 403 else 'FAIL',
            status,
            f'{ms:.0f}ms',
        )
    )

    status, ms, _ = request('GET', '/api/admin-panel/')
    results.append(('Admin panel HTML', 'PASS' if status in (200, 302) else 'FAIL', status, f'{ms:.0f}ms'))

    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
