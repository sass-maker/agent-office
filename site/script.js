const records = {
  research: {
    person: "Nia · Audience Researcher",
    title: "Finding the audience question",
    progress: 0.25,
    input: "Product brief",
    output: "Research notes",
    next: "Theo",
  },
  write: {
    person: "Theo · Content Writer",
    title: "Writing from shared evidence",
    progress: 0.5,
    input: "Nia's research",
    output: "Article draft",
    next: "Maya",
  },
  review: {
    person: "Maya · Editorial Manager",
    title: "Reviewing the actual work",
    progress: 0.78,
    input: "Theo's draft",
    output: "Approval or revision",
    next: "Theo or owner",
  },
  report: {
    person: "Maya · Editorial Manager",
    title: "Closing the day clearly",
    progress: 1,
    input: "Approved artifacts",
    output: "Owner's report",
    next: "Tomorrow",
  },
};

const steps = [...document.querySelectorAll(".day-step")];
const fields = {
  person: document.querySelector("[data-record-person]"),
  title: document.querySelector("[data-record-title]"),
  progress: document.querySelector("[data-record-progress]"),
  input: document.querySelector("[data-record-input]"),
  output: document.querySelector("[data-record-output]"),
  next: document.querySelector("[data-record-next]"),
};

function selectStep(step) {
  const record = records[step.dataset.scene];
  if (!record) return;

  steps.forEach((candidate) => {
    const active = candidate === step;
    candidate.classList.toggle("is-active", active);
    if (active) candidate.setAttribute("aria-current", "step");
    else candidate.removeAttribute("aria-current");
  });

  fields.person.textContent = record.person;
  fields.title.textContent = record.title;
  fields.progress.style.transform = `scaleX(${record.progress})`;
  fields.input.textContent = record.input;
  fields.output.textContent = record.output;
  fields.next.textContent = record.next;
}

if ("IntersectionObserver" in window) {
  const observer = new IntersectionObserver(
    (entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (visible) selectStep(visible.target);
    },
    { rootMargin: "-32% 0px -42%", threshold: [0.2, 0.55, 0.8] },
  );
  steps.forEach((step) => observer.observe(step));
}

const copyButton = document.querySelector("[data-copy-command]");
const copyStatus = document.querySelector("[data-copy-status]");
copyButton?.addEventListener("click", async () => {
  const command = "cd agent-office && swift run AgentOffice";
  try {
    await navigator.clipboard.writeText(command);
    copyStatus.textContent = "Copied to clipboard.";
    copyButton.textContent = "Copied";
  } catch {
    copyStatus.textContent = "Select the command above to copy it.";
  }
});
