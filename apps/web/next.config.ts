import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // @repo/ui exports raw .tsx source; let Next transpile it.
  transpilePackages: ["@repo/ui"],
};

export default nextConfig;
