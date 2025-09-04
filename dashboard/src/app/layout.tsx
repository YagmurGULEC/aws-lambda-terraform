import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: 'AWS Lambda Dashboard',
  description: 'Static dashboard to track AWS Lambda jobs via GitHub Pages',
  keywords: ['AWS Lambda',
    'GitHub Pages', 'Terraform', 'API Gateway',
    'AWS Lambda', 'SQS', 'Athena', 'DynamoDB', 'SQL Job Queue', 'Serverless Dashboard', 'Python', 'awswrangler', 'API Gateway', 'Plotly JS', 'Data Analytics', 'Asynchronous Jobs', 'Cloud Infrastructure', 'Terraform', 'CI/CD',
    'Dashboard', 'Balancing Yolo data'],
  authors: [{ name: 'Yagmur Gulec' }],
  metadataBase: new URL('https://yagmurgulec.github.io'),
  openGraph: {
    title: 'AWS Lambda Dashboard',
    description: 'Track Lambda job status using a static dashboard',
    url: 'https://yagmurgulec.github.io/aws-lambda-terraform/',
    type: 'website',
  },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
