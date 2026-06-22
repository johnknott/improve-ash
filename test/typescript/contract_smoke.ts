import {
  getEvent,
  getItem,
  getPlan,
  getSessionOccurrence,
  listEvents,
  listItemEffects,
  listItems,
  listPlans,
  listSessionOccurrences,
} from "../../priv/generated/ash_rpc.ts";
import type {
  EventInstanceResourceSchema,
  ItemEffectResourceSchema,
  ItemResourceSchema,
  PlanResourceSchema,
  SessionOccurrenceResourceSchema,
} from "../../priv/generated/ash_types.ts";

const planFields = ["id", "name", "startsOn"] as const satisfies readonly (keyof PlanResourceSchema)[];
const itemFields = ["id", "key", "facts"] as const satisfies readonly (keyof ItemResourceSchema)[];
const eventFields = ["id", "summary", "status"] as const satisfies readonly (keyof EventInstanceResourceSchema)[];
const effectFields = ["id", "effectType", "status"] as const satisfies readonly (keyof ItemEffectResourceSchema)[];
const occurrenceFields = ["id", "plannedFor", "status"] as const satisfies readonly (keyof SessionOccurrenceResourceSchema)[];

void [
  getEvent,
  getItem,
  getPlan,
  getSessionOccurrence,
  listEvents,
  listItemEffects,
  listItems,
  listPlans,
  listSessionOccurrences,
  planFields,
  itemFields,
  eventFields,
  effectFields,
  occurrenceFields,
];
