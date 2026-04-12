import type { BaseLayoutProps } from "fumadocs-ui/layouts/shared";
import { i18n } from "@/lib/i18n";
import { defineI18nUI } from "fumadocs-ui/i18n";

export const i18nUI = defineI18nUI(i18n, {
  translations: {
    en: {
      displayName: "English",
    },
    zh: {
      displayName: "中文",
      search: "搜索文档",
      searchNoResult: "未找到结果",
      toc: "目录",
      tocNoHeadings: "无标题",
      lastUpdate: "最后更新",
      chooseLanguage: "选择语言",
      nextPage: "下一页",
      previousPage: "上一页",
      chooseTheme: "选择主题",
    },
  },
});

export function baseOptions(locale: string): BaseLayoutProps {
  return {
    nav: {
      title: (
        <span className="font-semibold text-base">Multica Docs</span>
      ),
    },
    links: [
      {
        text: locale === "zh" ? "文档" : "Documentation",
        url: `/${locale}/docs`,
        active: "nested-url",
      },
      {
        text: "GitHub",
        url: "https://github.com/multica-ai/multica",
      },
      {
        text: locale === "zh" ? "云服务" : "Cloud",
        url: "https://multica.ai",
      },
    ],
  };
}
