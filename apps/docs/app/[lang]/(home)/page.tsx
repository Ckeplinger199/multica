import Link from "next/link";

const texts = {
  en: {
    title: "Multica Documentation",
    description:
      "The open-source managed agents platform. Turn coding agents into real teammates — assign tasks, track progress, compound skills.",
    getStarted: "Get Started",
  },
  zh: {
    title: "Multica 文档",
    description:
      "开源的托管智能体平台。将编程智能体变成真正的队友——分配任务、跟踪进度、积累技能。",
    getStarted: "快速开始",
  },
} as const;

export default async function HomePage({
  params,
}: {
  params: Promise<{ lang: string }>;
}) {
  const { lang } = await params;
  const t = texts[lang as keyof typeof texts] ?? texts.en;

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-6 text-center px-4">
      <h1 className="text-4xl font-bold tracking-tight sm:text-5xl">
        {t.title}
      </h1>
      <p className="max-w-2xl text-lg text-fd-muted-foreground">
        {t.description}
      </p>
      <div className="flex gap-4">
        <Link
          href={`/${lang}/docs`}
          className="inline-flex items-center rounded-md bg-fd-primary px-6 py-3 text-sm font-medium text-fd-primary-foreground transition-colors hover:bg-fd-primary/90"
        >
          {t.getStarted}
        </Link>
        <Link
          href="https://github.com/multica-ai/multica"
          className="inline-flex items-center rounded-md border border-fd-border px-6 py-3 text-sm font-medium transition-colors hover:bg-fd-accent"
        >
          GitHub
        </Link>
      </div>
    </main>
  );
}
