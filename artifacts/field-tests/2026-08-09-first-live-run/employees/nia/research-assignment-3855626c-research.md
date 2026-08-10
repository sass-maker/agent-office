> Evidence basis: `permitted-web-research`
> This brief used the owner's permitted web-research capability.

# Executive summary

The strongest next non-technical AI employee is a **Customer Voice Analyst**: a read-only employee that turns locally supplied customer conversations, survey responses, support exports, and founder notes into one inspectable weekly decision brief.

This role ranks above a content repurposing editor, growth reporting analyst, and founder chief of staff because it offers the best balance of:

- **Repeatability:** the same bounded review runs every week.
- **Measurable output:** coverage, issue frequency, evidence count, week-over-week movement, and recommended priorities can all be inspected.
- **Permission safety:** the first version only needs read access to a designated local folder.
- **Mac-first suitability:** inputs and reports can remain ordinary local files without cloud credentials or external writes.
- **Incremental product value:** it converts research and real customer evidence into priorities without duplicating the existing research employee or content team.

The concrete audience question worth answering is:

> “Once I have an AI researcher, which employee can turn what customers said this week into one evidence-backed decision for next week—without accessing or changing my business systems?”

# Findings

## Evidence supplied by the owner

The following are product constraints and claims from the owner-provided brief, not independently verified external facts:

- Agent Office is a native Mac workplace for named AI employees producing inspectable local work.
- Its current proof includes a researcher, executive assistant, content team, explicit skills, read-only research permission, local persistence, and bounded handoffs.
- The next role must be non-technical and must not require external writes, cloud credentials, or unsupported autonomy claims.
- A second generic researcher or broad content employee would add less differentiation because research and content capabilities already exist.

## External evidence

Customer-feedback analysis has unusually clear, inspectable units of work. Intercom’s current first-party documentation treats conversation topics, issue frequency, customer satisfaction, response time, resolution rate, and underlying conversations as useful reporting evidence. Its recommendation workflow also reviews real customer conversations, identifies recurring content, data, and action gaps, and ranks fixes by impact. This supports the underlying job-to-be-done for a weekly Customer Voice Analyst, although Agent Office would implement a narrower, local, read-only version rather than Intercom’s integrated service. [S1][S2]

Content repurposing is also repeatable: HubSpot documents turning existing text, pages, images, audio, or video into summaries, social posts, emails, and other formats. Its output volume is easy to count, but usefulness is harder to measure before publication, and Agent Office already claims a content team. [S3][S4]

Growth reporting has strong quantitative measures. Google Analytics documents acquisition reports that connect traffic sources with engagement and revenue-related metrics. However, a useful weekly growth analyst normally needs analytics access or recurring exports, and interpretation is vulnerable to scope and attribution mistakes; Google explicitly warns that similarly named metrics from user- and session-scoped reports should not be compared directly. [S5][S6]

A broad chief-of-staff role is attractive but poorly bounded for this product stage. Calendar, email, financial, strategic, and personnel context would expand read permissions substantially, while outputs such as “better coordination” are harder to verify than a fixed evidence report. This conclusion is an inference from the owner’s constraints rather than a claim established by an external source.

Apple documents that macOS can grant or revoke application access to specific protected file locations. That makes a designated local intake folder a credible permission boundary for the proposed role, though the product must still implement and demonstrate its own sandboxing correctly. [S7]

OpenAI’s current guidance reinforces two design requirements relevant to this employee: cited reports improve traceability, but model output can still contain incorrect facts or fabricated references and should be checked against source material. The employee should therefore link every finding to an exact local excerpt and expose uncertainty instead of presenting synthesis as fact. [S8][S9]

## Role comparison

Scores use a 1–5 scale, where 5 is most favorable. For permission safety, 5 means the narrowest and lowest-risk access. Scores are reasoned product judgments based on the owner constraints and cited workflow evidence.

| Candidate role | Weekly repeatability | Measurable output | Permission safety | Local Mac fit | Main weakness |
|---|---:|---:|---:|---:|---|
| **Customer Voice Analyst** | 5 | 5 | 4 | 5 | Needs a steady supply of customer evidence |
| Content Repurposing Editor | 5 | 3 | 5 | 5 | Duplicates the existing content team; business impact usually appears only after publishing |
| Growth Reporting Analyst | 5 | 5 | 2 | 3 | Usually requires analytics credentials or disciplined exports; attribution is easy to misread |
| Founder Chief of Staff | 4 | 2 | 1 | 3 | Broad sensitive context, ambiguous success criteria, and pressure toward external actions |

### Why the Customer Voice Analyst wins

1. **It forms a useful chain with the existing researcher.** The researcher studies markets and external questions; the Customer Voice Analyst examines first-party evidence about what actual users asked, struggled with, requested, or praised.

2. **Its work can be bounded precisely.** A weekly run can accept only files placed in one organization-controlled folder and produce only a Markdown report in a local output folder.

3. **Its quality is auditable.** The owner can check how many records were reviewed, whether each claim has supporting excerpts, how themes were counted, what changed from the prior week, and whether the recommendation follows from the evidence.

4. **It avoids premature autonomy.** It does not reply to customers, edit a CRM, publish content, change a roadmap, or open cloud accounts. It recommends; the owner decides.

5. **It creates downstream work without pretending to complete it.** Findings can become a research question, content brief, FAQ candidate, onboarding improvement, or founder decision through explicit handoffs.

## Narrow employee definition

**Employee:** Customer Voice Analyst

**Outcome:** Every week, convert the customer evidence deliberately placed in one local intake folder into a cited, decision-ready brief.

**Allowed inputs:** Local `.txt`, `.md`, `.csv`, or exported conversation files inside one selected organization directory.

**Required output:** One local Markdown report containing:

- input files and record count;
- top three customer themes;
- frequency and change from the previous comparable run;
- representative excerpts linked to their local sources;
- confidence and evidence gaps;
- one recommended founder priority;
- up to three bounded handoff suggestions.

**Explicitly prohibited:**

- accessing email, support, analytics, CRM, calendar, or financial systems directly;
- contacting customers;
- editing source records;
- publishing or sending output;
- making product or roadmap changes;
- inferring prevalence beyond the supplied sample.

## First weekly duty it should own

> **Every Monday, review all customer-feedback files added to the designated local inbox during the previous seven days and produce a cited “Customer Voice Weekly” brief identifying the most repeated customer problem and recommending exactly one owner decision for the coming week.**

Initial success measures:

- 100% of eligible supplied records accounted for;
- every reported theme supported by at least two source excerpts, or labeled as a single observation;
- exactly one prioritized recommendation;
- no reads outside the designated folder;
- no external writes or messages;
- owner can trace every factual claim back to a local source.

# Sources

- **S1 — Intercom, “AI-powered reporting & analytics for customer support teams.”** Conversation-topic reporting, issue trends, CSAT, resolution rate, response time, and drill-down into underlying conversations.  
  https://www.intercom.com/helpdesk/reporting

- **S2 — Intercom Help, “Optimize Fin instantly with the help of AI.”** Weekly analysis of real customer conversations, gap identification, impact scoring, and evidence-backed recommendations.  
  https://www.intercom.com/help/en/articles/11390088-optimize-fin-instantly-with-the-help-of-ai

- **S3 — HubSpot Knowledge Base, “Understand Breeze.”** Describes content remix as transforming existing material into summaries, social posts, emails, page drafts, and other formats.  
  https://knowledge.hubspot.com/ai/understand-breeze

- **S4 — HubSpot Knowledge Base, “Repurpose content with content remix.”** Documents repurposing existing text, pages, images, audio, and video into additional formats.  
  https://knowledge.hubspot.com/blog/repurpose-content-using-ai-with-content-remix

- **S5 — Google Analytics Help, “User acquisition report vs. Traffic acquisition report.”** Explains acquisition and engagement measures and warns about comparing metrics with different scopes.  
  https://support.google.com/analytics/answer/14731736?hl=en

- **S6 — Google Analytics Help, “Traffic acquisition report.”** Documents traffic-source dimensions and the use of acquisition reporting to understand new and returning visitors.  
  https://support.google.com/analytics/answer/12923437?co=GENIE.Platform%3DDesktop&hl=en-CA

- **S7 — Apple Support, “Control access to files and folders on Mac.”** Documents user control over application access to protected file locations.  
  https://support.apple.com/en-gb/guide/mac-help/-mchld5a35146/mac

- **S8 — OpenAI Help Center, “Deep research in ChatGPT.”** Documents structured research reports with citations or source links for verification.  
  https://help.openai.com/en/articles/10500283-deep-research-in-chatgpt

- **S9 — OpenAI Help Center, “Does ChatGPT tell the truth?”** Warns that models can produce incorrect facts and fabricated citations and recommends verification against reliable sources.  
  https://help.openai.com/en/articles/8313428-chatgpt-and-fake-citations

# Uncertainty

- No direct user interviews, usage telemetry, willingness-to-pay data, or retention data for Agent Office were supplied. The recommendation is therefore a product-fit inference, not validated demand.
- A Customer Voice Analyst is less useful before a founder has recurring customer conversations. For a pre-customer founder, the content repurposing editor may produce more weekly volume, though it remains less differentiated from the current product proof.
- The proposal assumes Agent Office can enforce folder-scoped reads and retain source references. The owner brief claims local and bounded execution, but this research did not independently inspect or test that implementation.
- Customer records can contain personal or commercially sensitive information even when stored locally. Local-only processing reduces integration exposure but does not eliminate privacy, retention, or access-control obligations.
- Counts from a convenience sample of support messages do not represent the whole market. The employee must distinguish “share of supplied records” from “share of customers.”
- The role comparison scores are judgment calls, not results from a controlled study.

# Recommended next actions

1. Prototype only the Monday **Customer Voice Weekly** duty; do not begin with live inbox or CRM integration.
2. Test it against three anonymized weekly fixture sets containing duplicates, contradictory feedback, sparse evidence, and personally identifying text.
3. Require source-level traceability, explicit denominators, duplicate handling, and confidence labels before evaluating prose quality.
4. Measure owner acceptance using five criteria: time saved, coverage accuracy, citation accuracy, priority usefulness, and permission-boundary compliance.
5. Interview five solo founders with recurring customer contact around the concrete question: **“Would one evidence-backed customer priority every Monday change what you do that week?”**
6. Expand the employee only after repeated successful runs; keep customer replies, CRM edits, publishing, and roadmap changes outside its authority.