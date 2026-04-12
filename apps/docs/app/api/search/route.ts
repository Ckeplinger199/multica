import { source } from "@/lib/source";
import { createFromSource } from "fumadocs-core/search/server";

export const { GET } = createFromSource(source, {
  localeMap: {
    zh: {
      // Orama doesn't have a built-in Chinese tokenizer,
      // so we disable language-specific stemming for zh
      language: undefined,
    },
  },
});
