export default function StatusBadge({ status, children }) {
  return (
    <span className="rounded px-2 py-0.5 text-xs font-medium bg-gray-500 text-white" data-status={status}>
      {children}
    </span>
  );
}
