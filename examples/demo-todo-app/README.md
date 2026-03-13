# Demo Todo App — BMB Showcase

A deliberately flawed Express.js + SQLite Todo API.
Use this project to watch BMB find and fix real-world issues end-to-end.

## Quick Start

```bash
cd examples/demo-todo-app
npm install
npm start          # http://localhost:3000
```

### API Endpoints

| Method | Path           | Description       |
|--------|----------------|-------------------|
| GET    | /todos         | List all todos    |
| GET    | /todos/:id     | Get one todo      |
| POST   | /todos         | Create a todo     |
| PUT    | /todos/:id     | Update a todo     |
| DELETE | /todos/:id     | Delete a todo     |

## BMB Demo Walkthrough

### 1. Install dependencies

```bash
cd examples/demo-todo-app && npm install
```

### 2. Open a tmux session

```bash
tmux new -s bmb-demo
```

### 3. Launch Claude Code

```bash
claude
```

### 4. Run BMB Setup

```
/BMB-setup
```

Follow the prompts to configure the project context.

### 5. Run BMB

```
/BMB
```

When prompted for a task, enter:

> Audit and fix all security and quality issues in this Todo API

### 6. Watch BMB work

BMB will spin up its full pipeline — consultant analysis, architect planning,
executor implementation, tester validation, verifier review, and simplifier cleanup.

By the end, you should see all major issues identified and resolved:
- Security vulnerabilities patched
- Input validation added
- Error handling improved
- Tests written
- Dependencies updated
- Edge cases covered

Check `.bmb-demo-bugs.md` after the run to verify BMB caught everything.
