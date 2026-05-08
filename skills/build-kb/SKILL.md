---
name: build-kb
description: Scan this project and generate a chatbot-ready knowledge-base.md
---

Generate a `knowledge-base.md` file in the repo root that a website chatbot can use to answer visitor questions. Read everything user-facing -- README, marketing copy, docs, product pages, pricing, support -- and organize it into a fixed set of categories. Never invent content.

## Step 1 -- Scope check

Confirm with the user, one short question, then proceed:

> Generating `knowledge-base.md` for a visitor-facing chatbot. Anything to exclude (private docs, internal tooling, drafts)? Press Enter to scan everything.

If they answer, respect the exclusions. Default scan covers the whole repo.

If `knowledge-base.md` already exists with uncommitted changes, ask before overwriting.

## Step 2 -- Discover sources (in parallel)

Use Glob + Grep to find user-facing content. Don't read code files unless they contain marketing strings (frontend page components do; backend utilities don't).

Look in the obvious places first:
- `README.md` (root) and any other root-level prose
- `package.json` -- name, description
- Frontend pages -- whatever the project uses (`app/`, `pages/`, `src/pages/`, `src/routes/`, `routes/`, `public/*.html`)
- Marketing components -- folders like `components/marketing`, `components/main`, `components/landing`
- Docs / content trees -- `docs/`, `content/`, `blog/`, any markdown directories
- Pricing / plans -- grep for "pricing", "plan", "tier", currency symbols in marketing files
- FAQ -- grep for "FAQ", "faq", "frequently asked"
- Support / contact -- grep for "contact", "support", "help"
- Policies -- files matching `privacy*`, `terms*`, `refund*`, `policy*`
- Brand voice -- `BRAND.md`, `VOICE.md`, brand guideline docs (only if present)

Read the discovered files in parallel. Stop when you have enough -- don't exhaust the repo.

## Step 3 -- Synthesize into eight sections

Output sections in this order:

1. **General** -- one-paragraph overview of what the company / product is
2. **About** -- story, team, mission, values
3. **Products** -- one subsection per product. **Capture everything the website says about that product** so a visitor's chatbot can answer any question about it. Include whatever applies: name, tagline, what it does, who it's for, problems it solves, features, capabilities, parameters / specs / inputs, supported integrations, limits, requirements, pricing if shown next to the product, deployment / install steps if shown, examples, screenshots' captions, and any callouts. Each product has different parameters -- don't force a fixed schema, just record what the website actually shows. If two products share fields (e.g. both have "supported platforms"), keep the field names consistent so the chatbot can compare them.
4. **FAQ** -- common questions and clear answers
5. **Policies** -- privacy / refund / terms highlights (link to full text if available)
6. **Tone** -- how the brand speaks (voice, do's/don'ts) -- only if explicit brand guidelines exist
7. **Pricing** -- plans, prices, what's included
8. **Support** -- contact channels, hours, response times

**Rules for synthesis:**
- Skip any category without source content. Do NOT fabricate.
- Short paragraphs, bullet lists, sentence case.
- Keep most sections under ~300 words. **Products is the exception** -- it's intentionally exhaustive per product so the chatbot has full coverage. Don't trim product details for length.
- Lift phrasing from marketing copy when it's crisp -- don't paraphrase good copy worse.
- Drop anything internal: drafts, TODOs, engineering notes, anything labeled "internal" or "private".

## Step 4 -- Write and report

Write the file to `knowledge-base.md` in the repo root (overwrite cleanly).

Then report:

```
knowledge-base.md generated.

Populated categories: General, About, Products, FAQ, Pricing, Support
Skipped: Policies (no privacy/refund docs found), Tone (no brand voice guide found)

Source files referenced:
- README.md
- ...

Next: paste each category section into your chatbot's KB entries.
```

## Rules

- Don't invent content -- only synthesize what's actually in the repo
- One output file: `knowledge-base.md`, repo root, overwrites cleanly
- Visitor-facing only -- no architecture or eng notes leak in
- If the repo has no marketing/product copy at all, say so honestly and stop
- No emojis in the output file
