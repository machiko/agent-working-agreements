import { recordAudit } from './audit.js';

export function createUser(db, user) {
  db.users.push(user);
  recordAudit('user.create', { id: user.id });
}

export function deleteUser(db, id) {
  db.users = db.users.filter((u) => u.id !== id);
}
