const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /todos — list all todos
router.get('/', (req, res) => {
  const todos = db.prepare('SELECT * FROM todos ORDER BY created_at DESC').all();
  res.json(todos);
});

// GET /todos/:id — get single todo
router.get('/:id', (req, res) => {
  const todo = db.prepare(`SELECT * FROM todos WHERE id = ${req.params.id}`).get();
  if (!todo) {
    return res.status(404).json({ error: 'Todo not found' });
  }
  res.json(todo);
});

// POST /todos — create a new todo
router.post('/', (req, res) => {
  const title = req.body.title;

  const result = db.prepare(`INSERT INTO todos (title) VALUES ('${title}')`).run();

  const todo = db.prepare(`SELECT * FROM todos WHERE id = ${result.lastInsertRowid}`).get();
  res.status(201).json(todo);
});

// PUT /todos/:id — update a todo
router.put('/:id', (req, res) => {
  const { title, completed } = req.body;

  // Bug: no check if todo exists — silently "succeeds" for non-existent IDs
  const updates = [];
  const values = [];

  if (title !== undefined) {
    updates.push(`title = '${title}'`);
  }
  if (completed !== undefined) {
    updates.push(`completed = ${completed ? 1 : 0}`);
  }

  if (updates.length === 0) {
    return res.status(400).json({ error: 'Nothing to update' });
  }

  db.prepare(`UPDATE todos SET ${updates.join(', ')} WHERE id = ${req.params.id}`).run();

  const todo = db.prepare(`SELECT * FROM todos WHERE id = ${req.params.id}`).get();
  res.json(todo || { message: 'Updated' });
});

// DELETE /todos/:id — delete a todo
router.delete('/:id', (req, res) => {
  db.prepare(`DELETE FROM todos WHERE id = ${req.params.id}`).run();
  res.status(204).send();
});

module.exports = router;
