---
name: execute-with-agents
description: Execute implementation plans using specialized agent contexts from docs/agents/
---

# Execute Plans with Specialized Agents

Execute implementation plans while following specialized agent guidance.

**Announce at start:** "I'm using execute-with-agents to implement this plan with specialized agent contexts."

## Step 1: Load Agent Contexts

**ALWAYS read these first:**
1. `docs/agents/shared-context.md` - Core patterns, ALWAYS read
2. Identify which specialists needed for this plan:
   - Rails work → `docs/agents/rails-context.md`
   - GraphQL work → `docs/agents/graphql-context.md`
   - Architecture decisions → `docs/agents/architecture-context.md`
   - Testing → `docs/agents/testing-context.md`

**Read all relevant contexts BEFORE starting implementation.**

## Step 2: Load and Review Plan

1. Read plan file
2. Review critically against agent contexts
3. Identify which agent patterns apply to each task
4. If concerns: Raise them before starting
5. If no concerns: Create TodoWrite and proceed

## Step 3: Execute Batch with Agent Guidance

**Default: First 3 tasks**

For each task:
1. Identify which agent context(s) apply
2. Re-read relevant sections from agent contexts
3. Mark task as in_progress
4. Follow plan steps AND agent patterns
5. Run verifications as specified
6. Mark as completed

**Key difference from base executing-plans:**
- Check agent contexts for each decision
- Follow patterns from relevant specialists
- TDD is mandatory (testing-context.md)

## Step 4: Report

When batch complete:
- Show what was implemented
- Show how you followed agent patterns
- Show verification output
- Say: "Ready for feedback."

## Step 5: Continue

Based on feedback:
- Apply changes if needed
- Execute next batch
- Repeat until complete

## Step 6: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- Use superpowers:finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice

## Agent Context Decision Tree

```
Task involves...
├─ Database schema → architecture-context.md
├─ GraphQL types/mutations → graphql-context.md
├─ Rails controllers/views → rails-context.md
├─ Services/jobs → architecture-context.md + shared-context.md
├─ Testing anything → testing-context.md (ALWAYS)
└─ LLM integration → shared-context.md (LLM patterns section)
```

## Remember

- Load agent contexts FIRST
- Follow agent patterns, not just plan steps
- TDD is mandatory (not optional)
- Check shared-context.md for every task
- Stop when blocked, consult relevant agent context
