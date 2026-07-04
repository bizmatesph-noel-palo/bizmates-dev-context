# ASC Project — Documentation Style Guide

## Summary

This guide defines how the ASC project structures methodology, process, and reference documentation. The goal is to present information in an order that serves the reader — practical content first, supporting evidence last.

---

## The Principle

When creating documentation, follow this information flow:

```
What is it → How we do it → Does it work → Is it credible
```

The reader's priority is understanding what something is and how to use it. Theoretical justification and external credibility are supporting material — they validate the approach but should never block the reader from reaching the practical content.

---

## Document Structure

### Section Order

| # | Section | Purpose | Reader question answered |
|---|---|---|---|
| 1 | **Summary / Overview** | What this document covers | "What am I reading?" |
| 2 | **The Concept** | What the method/process IS — diagrams, definitions, key terms | "What is it?" |
| 3 | **How It Works** | Practical steps, workflow, how the team executes it | "How do I use it?" |
| 4 | **Why It Works** | Theoretical justification, principles, reasoning | "Why should I trust this?" |
| 5 | **Strengths** | What it gives us, why it's effective | "What are the benefits?" |
| 6 | **Limitations** | What it doesn't cover, known gaps, mitigations | "What can go wrong?" |
| 7 | **Conclusion** | Brief summary statement | "What's the takeaway?" |
| 8 | **Appendix: References** | External evidence, citations, industry precedent | "Who else does this?" |

### Key Rules

- **Practical before theoretical.** The reader should understand the workflow before reading why it works.
- **Industry precedent goes last.** It validates the approach but is not a prerequisite for understanding it.
- **Each section should stand alone.** A reader who stops at section 3 should have enough to execute the process.
- **Strengths and Limitations before Conclusion.** The reader forms their own judgment before seeing the summary.
- **Appendix is optional reading.** External references support credibility but are not required to use the method.

---

## Why This Order Works

### The Reader's Mental Model

Readers approach documentation with a sequence of questions, each building on the previous:

```
1. "What is this?"          → Concept (orient me)
2. "How does it work?"      → Process (show me the steps)
3. "Why does it work?"      → Theory (convince me)
4. "Is it good enough?"     → Strengths + Limitations (help me decide)
5. "Who else uses this?"    → Precedent (reassure me)
```

If you put theory or citations before the process, readers must absorb abstract justification before understanding what they're justifying. This creates unnecessary cognitive load.

### Anti-Pattern: Theory First

```
❌ Bad order:
   Summary → Why it works → Industry Precedent → How it works → Strengths
```

This forces readers through Google DVT, MathWorks ISO 26262, and Netflix WAP before seeing the actual workflow steps. By the time they reach "How It Works," they've forgotten why they opened the document.

### Correct Pattern: Practice First

```
✅ Good order:
   Summary → What is it → How we do it → Why it works → Strengths → Limits → Conclusion → Appendix
```

The reader can stop at any point and still have value:
- Stop at section 2: knows what the method is
- Stop at section 3: can execute the process
- Stop at section 4: understands the reasoning
- Read to section 8: has full confidence with external validation

---

## Backing Principles

### 1. Inverted Pyramid (Technical Writing)

The inverted pyramid presents information in descending order of importance. The most critical content appears first so readers get the essential message even if they stop reading early.

Veeam's Technical Writing Style Guide states: the main idea is to present information in descending order of importance so that the most important concepts and statements are located at the top of the topic. Benefits include: readers can stop at any point and still get the main idea, and readers can quickly understand if they need the full text.

Content rephrased for compliance with licensing restrictions.

*(Sources: [Veeam Style Guide — Inverted Pyramid](https://helpcenter.veeam.com/docs/styleguide/tw/inverted_pyramid.html), [Purdue OWL — The Inverted Pyramid](https://owl.purdue.edu/owl/subject_specific_writing/journalism_and_journalistic_writing/the_inverted_pyramid.html))*

### 2. Progressive Disclosure (Cognitive Science / UX)

Progressive disclosure manages complexity by partitioning information into layers — showing essentials first, then revealing details as needed. When readers are confronted with too much information at once, cognitive overload sets in, making it harder to process, retain, or act on any of it.

The principle was coined by John M. Carroll at IBM in the 1980s during research on minimalist instruction. Nielsen Norman Group formalized it as a core UX design pattern. Applied to documentation: practical content is the "first layer" (what the reader needs immediately), theory is the "second layer" (what supports understanding), and external precedent is the "third layer" (what validates the choice).

Content rephrased for compliance with licensing restrictions.

*(Sources: [DevIQ — Progressive Disclosure](https://deviq.com/principles/progressive-disclosure/), [Nielsen Norman Group — Progressive Disclosure](https://www.nngroup.com), [arc42 — Progressive Disclosure](https://quality.arc42.org/approaches/progressive-disclosure))*

### 3. Task-Based Documentation (Google, Microsoft)

Google's Technical Writing course recommends organizing documents based on the audience's needs — addressing key questions in a clear and logical flow. Microsoft's style guide similarly prioritizes task-based content: "determine who the customer is and what task they're trying to do, then write to help that customer do that task."

Both emphasize: what the reader needs to DO comes before background theory. Our structure follows this — "How It Works" (the task) precedes "Why It Works" (the explanation).

Content rephrased for compliance with licensing restrictions.

*(Sources: [Google Technical Writing — Documents](https://developers.google.com/tech-writing/one/documents), [Microsoft Learn — Style Quick Start](https://learn.microsoft.com/en-us/contribute/content/style-quick-start))*

### 4. Divio Documentation System

The Divio documentation framework separates documentation into four distinct types, each serving a different purpose:

| Type | Orientation | Reader mode |
|---|---|---|
| Tutorials | Learning-oriented | "Teach me" |
| How-to guides | Task-oriented | "Show me how" |
| Explanation | Understanding-oriented | "Help me understand" |
| Reference | Information-oriented | "Give me the facts" |

The key insight: "how-to" (practical) and "explanation" (theoretical) are separate reader needs. Mixing them confuses both. Our structure respects this separation — process (sections 2-3) comes before theory (section 4) and reference material (section 8).

Content rephrased for compliance with licensing restrictions.

*(Source: [Divio — Documentation Structure](https://documentation.divio.com/structure/))*

### 5. IMRAD (Scientific Writing)

Scientific papers use IMRAD structure: Introduction → Methods → Results → Discussion. This is the dominant format in STEM publications (standardized in the 20th century, surveyed across 50 years of health sciences literature). The pattern is: context first, then how it was done, then what was found, then what it means.

Our structure adapts this for process documentation: Concept (Introduction) → How It Works (Methods) → Strengths/Limitations (Results) → Conclusion (Discussion). External precedent serves as an appendix — equivalent to a bibliography or supplementary materials section.

Content rephrased for compliance with licensing restrictions.

*(Source: [NIH/PMC — The IMRAD structure: a fifty-year survey](https://pmc.ncbi.nlm.nih.gov/articles/PMC442179/))*

---

## Scope

**Applies to:**
- Methodology documentation (e.g., `09_Verification_Methodology.md`)
- Process guides
- Design proposals
- Reference documentation
- Knowledge Base articles (when explaining a method or approach)

**Does NOT apply to:**
- Investigation reports (follow the Investigation Report Format in `SESSION_CONTEXT.md`)
- Test cases (follow their own `[Story] → [Precondition] → [Steps] → [Expected]` format)
- JIRA ticket drafts (follow JIRA conventions)
- Changelogs (chronological by nature)

---

## Checklist

When writing a new methodology or process document, verify:

- [ ] Summary is 1-2 sentences — reader knows what the doc covers immediately
- [ ] Concept section has a diagram or table — visual orientation before text
- [ ] "How It Works" is complete enough to execute without reading further sections
- [ ] Theory/reasoning comes AFTER the practical steps
- [ ] Strengths and limitations are honest — no overselling
- [ ] Conclusion is brief (3-5 sentences max) — not a repeat of the full document
- [ ] External references are in an appendix — not blocking the main content flow
- [ ] A reader who stops at section 3 still got value from the document
