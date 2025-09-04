"use client";

import { useEffect, useRef, useState } from "react";
import dynamic from "next/dynamic";
import Image from "next/image";
import type { Data as PlotData, Layout } from "plotly.js";

const Plot = dynamic(() => import("react-plotly.js"), { ssr: false });


type JobStatus = "queued" | "running" | "succeeded" | "failed";
type CreateJobResp = { job_id: string; status: JobStatus };
type Sql1Row = { label: string; instance_count: number };
type Sql2Row = { split: string; label: string; objects: number; pct_within_split: number };
type ApiResult = { sql_1: Sql1Row[]; sql_2: Sql2Row[] };

type GetJobResp = {
  job_id: string;
  status: JobStatus;
  progress?: number;
  result?: unknown;        // ← unknown, we’ll validate
  error?: string;
};

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE ??
  "https://baau72q1kd.execute-api.us-east-1.amazonaws.com/Prod";

// Type guard: checks unknown → ApiResult
function isApiResult(x: unknown): x is ApiResult {
  if (typeof x !== "object" || x === null) return false;
  if (!("sql_1" in x) || !("sql_2" in x)) return false;
  const y = x as { sql_1: unknown; sql_2: unknown };
  return Array.isArray(y.sql_1) && Array.isArray(y.sql_2);
}

export default function JobWithCharts() {
  const [status, setStatus] = useState<JobStatus | "idle">("idle");
  const [jobId, setJobId] = useState<string | null>(null);
  const [progress, setProgress] = useState(0);
  const [err, setErr] = useState<string | null>(null);
  const [data, setData] = useState<ApiResult | null>(null);

  const [chart1, setChart1] = useState<{ categories: string[]; values: number[] } | null>(null);
  const [chart2Traces, setChart2Traces] = useState<PlotData[] | null>(null);

  const abortRef = useRef<AbortController | null>(null);
  const simTimer = useRef<NodeJS.Timeout | null>(null);

  // Build grouped bar traces for sql_2 without any
  function buildChart2(
    sql2: Sql2Row[],
    labelOrder?: string[]
  ): { categories: string[]; traces: PlotData[] } {
    const categories =
      labelOrder && labelOrder.length
        ? [...labelOrder]
        : Array.from(new Set(sql2.map((r) => r.label))).sort();

    const splits = Array.from(new Set(sql2.map((r) => r.split)));

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

    const traces: PlotData[] = splits.map((split) => {
      const y = categories.map((label) => bySplit[split].get(label) ?? 0);
      // Use percentage labels so `text` isn’t “unused”
      const text = categories.map((label) => {
        const v = bySplit[split].get(label) ?? 0;
        const total = totalsPerSplit[split] || 1;
        return `${((v / total) * 100).toFixed(1)}%`;
      });

      const trace: PlotData = {
        type: "bar",
        name: split,
        x: categories,
        y,
        text,
        textposition: "auto",
      };
      return trace;
    });

    return { categories, traces };
  }

  // Simulated progress if API has no progress field
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
    abortRef.current?.abort();
    stopSimProgress();
    setErr(null);
    setChart1(null);
    setChart2Traces(null);
    setProgress(0);
    setStatus("queued");

    abortRef.current = new AbortController();

    try {
      startSimProgress(500, 10);

      const created = await createJob();
      setJobId(created.job_id);
      setStatus("running");

      let attempt = 0;
      const maxAttempts = 60;
      while (attempt < maxAttempts) {
        const resp = await getStatus(created.job_id);
        setStatus(resp.status);

        if (typeof resp.progress === "number" && !Number.isNaN(resp.progress)) {
          setProgress(Math.min(Math.max(0, resp.progress), resp.status === "succeeded" ? 100 : 95));
        }

        if (resp.status === "succeeded") {
          stopSimProgress();
          setProgress(100);

          const payload = typeof resp.result === "string" ? JSON.parse(resp.result) : resp.result;
          if (isApiResult(payload)) {
            setData(payload);
          } else {
            setErr("Unexpected result shape (missing sql_1/sql_2)");
          }
          return;
        }

        if (resp.status === "failed") {
          stopSimProgress();
          setErr(resp.error ?? "Job failed");
          return;
        }

        const delay = Math.min(500 * (attempt + 1), 5000);
        await new Promise((r) => setTimeout(r, delay));
        attempt++;
      }

      stopSimProgress();
      setErr("Polling timed out");
    } catch (e: unknown) {
      if (e instanceof DOMException && e.name === "AbortError") return;
      setErr(e instanceof Error ? e.message : "Unknown error");
      stopSimProgress();
    }
  };

  useEffect(() => {
    run();
    return () => {
      abortRef.current?.abort();
      stopSimProgress();
    };

  }, []);

  useEffect(() => {
    if (!data) return;

    const c1 = {
      categories: data.sql_1.map((d) => d.label),
      values: data.sql_1.map((d) => d.instance_count),
    };
    setChart1(c1);

    const c2 = buildChart2(data.sql_2, c1.categories);
    setChart2Traces(c2.traces);
  }, [data]);

  return (
    <div className="min-h-screen grid place-items-center p-6">
      <main className="w-full max-w-6xl space-y-6 px-4">
        <header className="flex items-center justify-between">

          <h1 className="text-2xl font-semibold">Athena-Powered Dashboard with SQS/Lambda Backend</h1>

          <button
            onClick={run}
            className="rounded-md border px-3 py-1.5 text-sm hover:bg-black/5 dark:hover:bg-white/10"
            disabled={status === "running" || status === "queued"}
          >
            {status === "running" || status === "queued" ? "Running…" : "Run again"}
          </button>
        </header>
        <div className="space-y-2 w-full">


          <div className="w-full overflow-hidden rounded-lg border">
            <Image
              src="/graph.svg"
              alt="Graph"
              width={1600}
              height={900}
              className="w-full h-auto"
            />
          </div>
          <h1 className="text-2xl font-semibold">SQL-Based Label Statistics and Stratified Dataset Partitioning for Object Detection Using the Pascal VOC Dataset</h1>
        </div>
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

        <div className="rounded border p-4 space-y-1 text-sm">

          {err && <p className="text-red-600"><strong>Error:</strong> {err}</p>}
        </div>

        {status === "succeeded" && chart1 && (
          <Plot
            data={[
              {
                x: chart1.categories,
                y: chart1.values,
                type: "bar",
                marker: { color: "steelblue" },
              } as PlotData,
            ]}
            layout={{
              title: { text: "Object Instances (All Data)" },
              xaxis: { title: { text: "Label" } },
              yaxis: { title: { text: "Instances" } },
              margin: { l: 60, r: 20, b: 80, t: 60 },
              autosize: true,
              height: 400,
            } as Partial<Layout>}
            style={{ width: "100%", height: "100%" }}
            useResizeHandler
            config={{ displayModeBar: false }}
          />
        )}

        {status === "succeeded" && chart2Traces && (
          <Plot
            data={chart2Traces}
            layout={{
              title: { text: "Objects per Label (by Split)" },
              barmode: "group",
              xaxis: { title: { text: "Label" }, tickangle: -30 },
              yaxis: { title: { text: "Objects" } },
              margin: { l: 60, r: 20, b: 80, t: 60 },
              autosize: true,
              height: 420,
            } as Partial<Layout>}
            style={{ width: "100%", height: "100%" }}
            useResizeHandler
            config={{ displayModeBar: false }}
          />

        )}
      </main>
    </div>
  );
}
