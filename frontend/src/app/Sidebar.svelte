<script lang="ts">
    import {
        Boxes,
        Calendar,
        ChevronUp,
        ClipboardList,
        Layers,
        LogOut,
        Moon,
        NotebookPen,
        Route,
        Settings,
        Sun,
        Tags,
        TrendingUp,
    } from "@lucide/svelte";
    import { DropdownMenu } from "bits-ui";
    import type { CurrentUser } from "../features/auth/authClient";
    import type { DashboardData } from "../api/types";
    import { logoutCurrentUser } from "../features/auth/authStore";
    import { theme, toggleTheme } from "../lib/theme";
    import PlanSwitcher from "./PlanSwitcher.svelte";
    import { activeRoute, navigate, type AppRoute } from "./routes";

    let {
        data,
        user,
        busy = false,
        loading = false,
        compact = false,
        open = false,
        onNavigate = () => {},
    }: {
        data: DashboardData | null;
        user: CurrentUser;
        busy?: boolean;
        loading?: boolean;
        compact?: boolean;
        open?: boolean;
        onNavigate?: () => void;
    } = $props();

    type NavItem = { id: AppRoute; label: string; icon: typeof Sun };

    const mainNav: NavItem[] = [
        { id: "today", label: "Today", icon: Sun },
        { id: "journal", label: "Journal", icon: NotebookPen },
        { id: "calendar", label: "Calendar", icon: Calendar },
    ];

    const planNav: NavItem[] = [
        { id: "plan", label: "Plan", icon: Route },
        { id: "progress", label: "Progress", icon: TrendingUp },
        { id: "sessions", label: "Sessions", icon: ClipboardList },
        { id: "inventory", label: "Inventory", icon: Boxes },
    ];

    const setupNav: NavItem[] = [
        { id: "event-types", label: "Event Types", icon: Tags },
        { id: "item-types", label: "Item Types", icon: Layers },
    ];

    function go(route: AppRoute) {
        navigate(route);
        onNavigate();
    }

    const horizontalOffset = 6;

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

<aside
    id="app-sidebar"
    class:open
    class="sidebar"
    aria-label="Application navigation"
    aria-hidden={compact && !open ? "true" : undefined}
    inert={compact && !open ? true : undefined}
>
    <div class="sidebar-header">
        <img class="brand-mark" src="/logo.svg" alt="" />
        <span class="brand-name">Improve</span>
        <button
            class="theme-toggle"
            type="button"
            aria-label={$theme === "dark" ? "Switch to light theme" : "Switch to dark theme"}
            onclick={toggleTheme}
        >
            {#if $theme === "dark"}
                <Sun size={16} />
            {:else}
                <Moon size={16} />
            {/if}
        </button>
    </div>

    <PlanSwitcher
        plans={data?.plans ?? []}
        currentPlan={data?.currentPlan ?? null}
        {busy}
        {loading}
        {onNavigate}
    />

    <nav class="nav-groups" aria-label="Primary">
        <div class="nav-group">
            <p>Main</p>
            {#each mainNav as item (item.id)}
                {@const Icon = item.icon}
                <button
                    class="nav-item"
                    class:active={$activeRoute.route === item.id}
                    aria-current={$activeRoute.route === item.id ? "page" : undefined}
                    type="button"
                    onclick={() => go(item.id)}
                >
                    <span class="nav-icon"><Icon size={16} /></span>
                    <span>{item.label}</span>
                </button>
            {/each}
        </div>

        <div class="nav-group">
            <p>Current plan</p>
            {#each planNav as item (item.id)}
                {@const Icon = item.icon}
                <button
                    class="nav-item"
                    class:active={$activeRoute.route === item.id}
                    aria-current={$activeRoute.route === item.id ? "page" : undefined}
                    type="button"
                    onclick={() => go(item.id)}
                >
                    <span class="nav-icon"><Icon size={16} /></span>
                    <span>{item.label}</span>
                </button>
            {/each}
        </div>

        <div class="nav-group">
            <p>Setup</p>
            {#each setupNav as item (item.id)}
                {@const Icon = item.icon}
                <button
                    class="nav-item"
                    class:active={$activeRoute.route === item.id}
                    aria-current={$activeRoute.route === item.id ? "page" : undefined}
                    type="button"
                    onclick={() => go(item.id)}
                >
                    <span class="nav-icon"><Icon size={16} /></span>
                    <span>{item.label}</span>
                </button>
            {/each}
        </div>
    </nav>

    <div class="sidebar-footer">
        <DropdownMenu.Root>
            <DropdownMenu.Trigger
                class="user-chip"
                onpointerdown={capturePointer}
            >
                <span class="avatar"
                    >{user.fullName?.slice(0, 1) ??
                        user.email.slice(0, 1).toUpperCase()}</span
                >
                <div>
                    <strong>{user.fullName ?? user.email}</strong>
                    <small>{user.email}</small>
                </div>
                <ChevronUp class="user-menu-icon" size={16} />
            </DropdownMenu.Trigger>

            <DropdownMenu.Portal>
                <DropdownMenu.Content
                    class="dropdown-content user-menu-content"
                    customAnchor={anchor}
                    side="top"
                    align="start"
                    sideOffset={10}
                >
                    <DropdownMenu.Item
                        class="dropdown-item dropdown-action"
                        onclick={() => go("item-types")}
                    >
                        <Settings size={16} />
                        <span>Settings</span>
                    </DropdownMenu.Item>
                    <div class="dropdown-separator"></div>
                    <DropdownMenu.Item
                        class="dropdown-item dropdown-danger"
                        onclick={logoutCurrentUser}
                    >
                        <LogOut size={16} />
                        <span>Logout</span>
                    </DropdownMenu.Item>
                </DropdownMenu.Content>
            </DropdownMenu.Portal>
        </DropdownMenu.Root>
    </div>
</aside>
