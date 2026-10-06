# BDD Acceptance Criteria Guide

Guidelines for writing crisp, testable Behaviour-Driven Development (BDD) acceptance criteria in DevFlow tasks.

## Format: Given / When / Then

Acceptance criteria define observable, binary pass/fail contracts using Gherkin syntax:

```gherkin
Given [initial state or preconditions]
When [single action or event trigger]
Then [observable, measurable outcome]
```

### Keyword Rules

- **Given**: Describes existing system or user context before interaction begins.
- **When**: Describes the single trigger event under test (user action, system timer, external webhook).
- **Then**: Asserts the externally visible outcome for the user or calling system.
- **And / But**: Chains additional preconditions or outcomes for readability. Never chain a second action.

## Core Rules

### 1. Exactly One `When` Per Scenario

Every scenario tests one specific behavior.

- **Prohibited:** `When user enters email And clicks submit And clicks confirm...`
- **Correction:** Split into sequential scenarios or focus the scenario on the specific decision under test.

### 2. Intent Over Mechanics (No Prescriptive UI)

Describe what the user wants to accomplish, not click-by-click mechanics or cosmetic styling.

- ❌ `When user clicks the round green button at the bottom right`
- ✅ `When user confirms order submission`

### 3. Zero Technical Implementation Leaks

Criteria must be understandable to domain experts. Never mention database tables, SQL queries, internal class names, or HTTP status codes unless specifying an external public API contract.

- ❌ `Then server returns 401 and writes record to users table`
- ✅ `Then access is denied and login prompt is displayed`

### 4. Occam's Razor

Strip away unnecessary specifics. If error recovery is identical across server failures, do not create redundant scenarios for 500, 502, 503.

### 5. Mandatory Async Lifecycle Coverage

For every asynchronous or stateful mutation:

1. **In-Flight / Loading State:** Visual indicator displayed (spinner/skeleton) and interactive controls disabled to prevent double-submission.
2. **Success State:** Observable confirmation, screen update, or navigation.
3. **Failure State:** Clear, non-technical error notification and recovery/retry path available.
4. **Empty State:** Clean fallback state displayed when queries return zero results.
