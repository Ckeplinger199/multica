import { RootProvider } from "fumadocs-ui/provider";
import type { ReactNode } from "react";
import { i18nUI } from "@/lib/layout.shared";

export default async function LangLayout({
  params,
  children,
}: {
  params: Promise<{ lang: string }>;
  children: ReactNode;
}) {
  const { lang } = await params;

  return (
    <html lang={lang} suppressHydrationWarning>
      <body>
        <RootProvider i18n={i18nUI.provider(lang)}>{children}</RootProvider>
      </body>
    </html>
  );
}
