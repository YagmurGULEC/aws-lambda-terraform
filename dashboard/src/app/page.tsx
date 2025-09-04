"use client";

import { useEffect, useRef, useState } from "react";
import dynamic from "next/dynamic";

const Plot = dynamic(() => import("react-plotly.js"), { ssr: false });

type JobStatus = "queued" | "running" | "succeeded" | "failed";

type CreateJobResp = { job_id: string; status: JobStatus };

type APIResult =
  | {
    // preferred structured shape
    chart1: { categories: string[]; values: number[] };
    chart2: { categories: string[]; values: number[] };
  }
  | unknown; // fallback for custom shapes

type GetJobResp = {
  job_id: string;
  status: JobStatus;
  progress?: number; // 0..100 if your API returns it
  result?: APIResult;
  error?: string;
};
type Sql1Row = { label: string; instance_count: number };
type Sql2Row = { split: string; label: string; objects: number; pct_within_split: number };
type ApiResult = { sql_1: Sql1Row[]; sql_2: Sql2Row[] };
const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ??
  "https://baau72q1kd.execute-api.us-east-1.amazonaws.com/Prod";

export default function JobWithCharts() {
  const [status, setStatus] = useState<JobStatus | "idle">("idle");
  const [jobId, setJobId] = useState<string | null>(null);
  const [progress, setProgress] = useState(0);
  const [err, setErr] = useState<string | null>(null);
  const [data, setData] = useState<ApiResult | null>(null);
  // normalized results for the two separate bar charts
  const [chart1, setChart1] = useState<{ categories: string[]; values: number[] } | null>(null);

  const [chart2Traces, setChart2Traces] = useState<any[] | null>(null);


  const abortRef = useRef<AbortController | null>(null);
  const simTimer = useRef<NodeJS.Timeout | null>(null); // used only if API has no progress
  function buildChart2(
    sql2: Sql2Row[],
    labelOrder?: string[] // optional: pass sql_1 order to keep charts aligned
  ): { categories: string[]; traces: any[] } {
    // pick label order: prefer sql_1 order if provided; else derive from sql_2
    const categories =
      labelOrder && labelOrder.length
        ? [...labelOrder]
        : Array.from(new Set(sql2.map(r => r.label))).sort();

    // unique splits, e.g. ["train", "val"]
    const splits = Array.from(new Set(sql2.map(r => r.split)));

    // aggregate counts per split+label
    const bySplit: Record<string, Map<string, number>> = {};
    const totalsPerSplit: Record<string, number> = {};
    for (const s of splits) {
      bySplit[s] = new Map();
      totalsPerSplit[s] = 0;
    }
    for (const row of sql2) {
      const prev = bySplit[row.split].get(row.label) ?? 0;
      bySplit[row.split].set(row.label, prev + row.objects);
      totalsPerSplit[row.split] += row.objects;
    }

    // traces for plotly (grouped bars)
    const traces = splits.map(split => {
      const y = categories.map(label => bySplit[split].get(label) ?? 0);
      // optional: show percentage text on bars (comment out if not needed)
      const text = categories.map(label => {
        const v = bySplit[split].get(label) ?? 0;
        const total = totalsPerSplit[split] || 1;
        return `${((v / total) * 100).toFixed(1)}%`;
      });

      return {
        type: "bar",
        name: split,
        x: categories,
        y,
        // text, textposition: "auto",  // uncomment to show percentages on bars
      };
    });

    return { categories, traces };
  }
  // --- utils to manage simulated progress when API doesn't provide it
  const startSimProgress = (intervalMs = 500, jump = 10) => {
    stopSimProgress();
    simTimer.current = setInterval(() => {
      setProgress((p) => (p < 95 ? Math.min(p + jump, 95) : p));
    }, intervalMs);
  };
  const stopSimProgress = () => {
    if (simTimer.current) clearInterval(simTimer.current);
    simTimer.current = null;
  };

  const createJob = async (): Promise<CreateJobResp> => {
    const res = await fetch(`${API_BASE}/jobs`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      // TODO: adjust payload to your API
      body: JSON.stringify({ params: { sql_1: "true", sql_2: "true" } }),
      signal: abortRef.current?.signal,
    });
    if (!res.ok) {
      const t = await res.text().catch(() => "");
      throw new Error(`Create job failed: ${res.status} ${res.statusText} ${t}`);
    }
    return res.json();
  };

  const getStatus = async (id: string): Promise<GetJobResp> => {
    const res = await fetch(`${API_BASE}/jobs/${id}`, {
      method: "GET",
      headers: { "Content-Type": "application/json" },
      signal: abortRef.current?.signal,
    });
    if (!res.ok) {
      const t = await res.text().catch(() => "");
      throw new Error(`Get status failed: ${res.status} ${res.statusText} ${t}`);
    }
    return res.json();
  };



  const run = async () => {
    abortRef.current?.abort(); // cancel any previous run
    stopSimProgress();
    setErr(null);
    setChart1(null);
    setChart2Traces(null);
    setProgress(0);
    setStatus("queued");

    abortRef.current = new AbortController();

    try {
      // start simulated progress NOW (we'll override with real progress if available)
      startSimProgress(500, 10); // every 500ms jump +10 until 95

      const created = await createJob();
      setJobId(created.job_id);
      setStatus("running");

      // poll
      let attempt = 0;
      const maxAttempts = 60; // ~ plenty; backoff below
      while (attempt < maxAttempts) {
        const resp = await getStatus(created.job_id);

        setStatus(resp.status);

        // If the API reports real progress, drive the bar with it (but keep cap at 95 until done)
        if (typeof resp.progress === "number" && !Number.isNaN(resp.progress)) {
          setProgress(Math.min(Math.max(0, resp.progress), resp.status === "succeeded" ? 100 : 95));
        }

        if (resp.status === "succeeded") {
          stopSimProgress();
          setProgress(100);

          const payload = resp.result; // could be object or string
          let parsed: ApiResult | null = null;

          try {
            const maybe = typeof payload === "string" ? JSON.parse(payload) : payload;

            if (
              maybe &&
              typeof maybe === "object" &&
              Array.isArray((maybe as any).sql_1) &&
              Array.isArray((maybe as any).sql_2)
            ) {
              parsed = maybe as ApiResult;
            } else {
              throw new Error("Unexpected result shape (missing sql_1/sql_2)");
            }
          } catch (e: any) {
            setErr(`Failed to parse result: ${e.message ?? e}`);
            return;
          }

          setData(parsed);
          return;
        }
        if (resp.status === "failed") {
          stopSimProgress();
          setErr(resp.error ?? "Job failed");
          return;
        }

        // backoff: 0.5s, 1s, 1.5s, ... up to 5s
        const delay = Math.min(500 * (attempt + 1), 5000);
        await new Promise((r) => setTimeout(r, delay));
        attempt++;
      }

      stopSimProgress();
      setErr("Polling timed out");
    } catch (e: any) {
      if (e?.name !== "AbortError") setErr(e?.message ?? "Unknown error");
      stopSimProgress();
    }
  };

  // auto-run on mount (optional). Or remove and call run() from a button.
  useEffect(() => {
    run();
    return () => {
      abortRef.current?.abort();
      stopSimProgress();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!data) return;
    // --- Chart 1: sql_1 (counts per label)
    const c1 = {
      categories: data.sql_1.map(d => d.label),
      values: data.sql_1.map(d => d.instance_count),
    };

    // --- Chart 2: sql_2 (counts per label, grouped by split)

    const c2 = buildChart2(data.sql_2, c1.categories);
    setChart2Traces(c2.traces);
    // store traces somewhere or just inline them in the Plot below
    (window as any).__chart2Traces = c2.traces; // or keep in state if you prefer
    setChart1(c1);

  }, [data]);

  return (
    <div className="min-h-screen grid place-items-center p-6">
      <main className="w-full max-w-3xl space-y-6">
        <header className="flex items-center justify-between">
          <h1 className="text-2xl font-semibold">Pascal VOC data distribution</h1>
          <button
            onClick={run}
            className="rounded-md border px-3 py-1.5 text-sm hover:bg-black/5 dark:hover:bg-white/10"
            disabled={status === "running" || status === "queued"}
          >
            {status === "running" || status === "queued" ? "Running…" : "Run again"}
          </button>
        </header>

        {/* Progress */}
        {(status === "queued" || status === "running") && (
          <div className="space-y-2">
            <div className="w-full h-3 rounded bg-black/10 dark:bg-white/10 overflow-hidden">
              <div
                className="h-full bg-black/70 dark:bg-white/80 transition-all"
                style={{ width: `${Math.round(progress)}%` }}
                role="progressbar"
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={Math.round(progress)}
              />
            </div>
            <div className="text-sm opacity-70">
              {status === "queued" ? "Queuing…" : "Running…"} {Math.round(progress)}%
            </div>
          </div>
        )}

        {/* Status / errors */}
        <div className="rounded border p-4 space-y-1 text-sm">

          {err && <p className="text-red-600"><strong>Error:</strong> {err}</p>}
        </div>


        <div className="space-y-8">
          {status === "succeeded" && data && chart1 && (
            <div className="space-y-8">
              <Plot
                data={[
                  {
                    x: chart1.categories,
                    y: chart1.values,
                    type: "bar",
                    marker: { color: "steelblue" },
                  },
                ]}
                layout={{
                  title: "Object Instances (All Data)",
                  xaxis: { title: "Label" },
                  yaxis: { title: "Instances" },
                  margin: { l: 60, r: 20, b: 80, t: 60 },
                  autosize: true,
                  height: 400,
                }}
                style={{ width: "100%", height: "100%" }}
                useResizeHandler
              />
            </div>

          )}
        </div>
        <div className="space-y-8">
          {status === "succeeded" && data && chart2Traces && (
            <div className="space-y-8">
              <Plot
                data={chart2Traces}
                layout={{
                  title: "Objects per Label (by Split)",
                  barmode: "group",            // side-by-side bars for train vs val
                  xaxis: { title: "Label", tickangle: -30 }, // angle helps if many labels
                  yaxis: { title: "Objects" },
                  margin: { l: 60, r: 20, b: 80, t: 60 },
                  autosize: true,
                  height: 420,
                }}
                style={{ width: "100%", height: "100%" }}
                useResizeHandler
                config={{ displayModeBar: false }}
              />
            </div>

          )}
        </div>
      </main>
    </div>
  );
}
