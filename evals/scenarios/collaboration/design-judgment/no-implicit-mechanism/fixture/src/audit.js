export const auditLog = [];

export function recordAudit(action, payload) {
  auditLog.push({ action, payload });
}
