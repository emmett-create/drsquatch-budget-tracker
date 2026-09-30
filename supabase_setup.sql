-- Run this in Supabase → SQL Editor (in the SAME shared project as
-- madegood-budget-tracker / moonjuice-budget-tracker / tacgrowth-budget-tracker
-- — Emmett's call, 2026-09-30: reuse the shared free-tier project rather
-- than set up a new one).
--
-- Brand-new tracker, built with Lumanu + the DocuSign inbox already in from
-- day one — no migration history to replay, just the final schema. Single
-- category (Emmett's call, 2026-09-30) — no a8_paid/{client}_paid/shipping
-- split, so every row is Lumanu-eligible once it has a source
-- ('invoice_email') or attached invoice.

CREATE TABLE drsquatch_budget_entries (
  id                uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  date              date NOT NULL,
  category          text CHECK (category IN ('paid_influencers')),
  entry_type        text NOT NULL DEFAULT 'actual' CHECK (entry_type IN ('actual', 'planned')),
  creator_handle    text,
  description       text,
  amount            numeric(12, 2) NOT NULL,
  notes             text,
  status            text NOT NULL DEFAULT 'confirmed',        -- 'pending' = sitting in the Needs Review inbox
  source            text NOT NULL DEFAULT 'manual',            -- 'invoice_email' | 'manual' | (docusign zap, if added later)
  ready_to_invoice  boolean NOT NULL DEFAULT false,
  billing_id        text,                                      -- Lumanu ID or billing email
  due_date          date,
  po_number         text,
  lumanu_status     text NOT NULL DEFAULT 'not_sent'
    CHECK (lumanu_status IN ('not_sent','needs_approval','approved','pending','issued','canceled')),
  lumanu_payable_id text,                                     -- set once actually sent to Lumanu; prevents double-sends
  invoice_path      text,                                     -- path in the private "invoices" Storage bucket
  contract_link     text,                                     -- plain link to the signed contract (DocuSign or any URL)
  planned_amount    numeric(12, 2),                            -- unused (Planned was retired 2026-09-22), kept for schema parity
  created_at        timestamptz DEFAULT now()
);

-- Allow public read/write (no login required — internal tool, same as every other tracker)
ALTER TABLE drsquatch_budget_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read"   ON drsquatch_budget_entries FOR SELECT USING (true);
CREATE POLICY "Public insert" ON drsquatch_budget_entries FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update" ON drsquatch_budget_entries FOR UPDATE USING (true);
CREATE POLICY "Public delete" ON drsquatch_budget_entries FOR DELETE USING (true);

-- Only needed if this shared project was created after Supabase's 2026-10-30
-- policy change (see moonjuice-budget-tracker/supabase_setup.sql) — since it
-- predates that, skip this unless the Data API can't reach the table:
--   grant select on public.drsquatch_budget_entries to anon;
--   grant select, insert, update, delete on public.drsquatch_budget_entries to authenticated;
--   grant select, insert, update, delete on public.drsquatch_budget_entries to service_role;

-- Reuses the existing "invoices" Storage bucket already created for
-- MadeGood/Moon Juice/TAC Growth — paths are namespaced by client, so no
-- collision. Nothing to create here.
