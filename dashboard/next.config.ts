import type { NextConfig } from "next";
const isGH = process.env.GH_PAGES === "true";

const repo = "aws-lambda-terraform"; // project page path
process.env.NEXT_PUBLIC_BASE_PATH = isGH ? `/${repo}` : "";
const nextConfig: NextConfig = {
  output: "export",
  basePath: isGH ? `/${repo}` : "",
  assetPrefix: isGH ? `/${repo}/` : "",
  images: { unoptimized: true },
  trailingSlash: true,
};

export default nextConfig;
