export function ComingSoon({ title, description }: { title: string; description?: string }) {
  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-bold">{title}</h1>
      <div className="rounded-xl border border-dashed border-neutral-300 p-12 text-center dark:border-navy-700">
        <p className="font-medium text-neutral-500">🚧 Page en construction</p>
        {description ? <p className="mt-1 text-sm text-neutral-400">{description}</p> : null}
      </div>
    </div>
  );
}
