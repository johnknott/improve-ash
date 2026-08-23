<script lang="ts">
    import {
        Check,
        ChevronDown,
        ListChecks,
        Pencil,
        Plus,
    } from "@lucide/svelte";
    import { DropdownMenu } from "bits-ui";
    import type { Plan } from "../api/types";
    import { changeSelectedPlan } from "./dashboardState";
    import { openEditPlanDialog, openNewPlanDialog } from "./uiState";

    let {
        plans,
        currentPlan,
        busy = false,
        loading = false,
        onNavigate = () => {},
    }: {
        plans: Plan[];
        currentPlan: Plan | null;
        busy?: boolean;
        loading?: boolean;
        onNavigate?: () => void;
    } = $props();

    async function selectPlan(planId: string) {
        onNavigate();
        await changeSelectedPlan(planId);
    }

    function editPlan(plan: Plan) {
        onNavigate();
        openEditPlanDialog(plan);
    }

    function newPlan() {
        onNavigate();
        openNewPlanDialog();
    }

    const horizontalOffset = 10;

    let anchor = $state<{ getBoundingClientRect: () => DOMRect } | null>(null);

    function capturePointer(event: PointerEvent) {
        const x = event.clientX;
        const y = event.clientY;
        anchor = {
            getBoundingClientRect: () =>
                new DOMRect(x + horizontalOffset, y, 0, 0),
        };
    }
</script>

<DropdownMenu.Root>
    <DropdownMenu.Trigger class="plan-switcher" disabled={busy} onpointerdown={capturePointer}>
        <ListChecks class="plan-switcher-icon" size={18} />
        <span class="plan-switcher-copy">
            <strong>{loading ? "Loading plans" : (currentPlan?.name ?? "No plan")}</strong>
            <span>
                {loading
                    ? "Opening your workspace"
                    : (currentPlan?.dayLabel ?? "Create or import a plan")}
            </span>
        </span>
        <ChevronDown class="plan-switcher-icon" size={16} />
    </DropdownMenu.Trigger>

    <DropdownMenu.Portal>
        <DropdownMenu.Content
            class="dropdown-content"
            customAnchor={anchor}
            align="start"
            sideOffset={20}
        >
            {#if plans.length}
                {#each plans as plan (plan.id)}
                    <DropdownMenu.Item
                        class="dropdown-item"
                        onclick={() => selectPlan(plan.id)}
                    >
                        <span class="plan-option">
                            <span>{plan.name}</span>
                            {#if plan.id === currentPlan?.id}
                                <Check size={15} />
                            {/if}
                        </span>
                        <small>{plan.dayLabel}</small>
                    </DropdownMenu.Item>
                {/each}
                <div class="dropdown-separator"></div>
            {/if}

            {#if currentPlan}
                <DropdownMenu.Item
                    class="dropdown-item dropdown-action"
                    onclick={() => editPlan(currentPlan)}
                >
                    <Pencil size={16} />
                    <span>Edit plan</span>
                </DropdownMenu.Item>
            {/if}

            <DropdownMenu.Item
                class="dropdown-item dropdown-action"
                onclick={newPlan}
            >
                <Plus size={16} />
                <span>New plan</span>
            </DropdownMenu.Item>
        </DropdownMenu.Content>
    </DropdownMenu.Portal>
</DropdownMenu.Root>

<style>
    .plan-option {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 0.5rem;
        color: inherit;
        font-weight: 600;
    }

    .plan-option :global(svg) {
        color: var(--brand-strong);
    }
</style>
