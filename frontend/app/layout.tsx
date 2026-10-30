import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Cours DevOps 2",
  description: "Site de présentation des cours du module DevOps 2 (TP3).",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  );
}
