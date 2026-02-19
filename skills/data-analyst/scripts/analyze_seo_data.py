#!/usr/bin/env python3
"""
SEO Data Analysis Script for SEOcrawler V2
Analyzes crawl data and generates statistical insights
"""

import sys
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json
import psycopg2
from typing import Dict, List, Any
import matplotlib.pyplot as plt
import seaborn as sns

class SEODataAnalyzer:
    def __init__(self, connection_string: str):
        self.conn = psycopg2.connect(connection_string)

    def fetch_crawl_data(self, days: int = 30) -> pd.DataFrame:
        """Fetch crawl data from last N days"""
        query = """
        SELECT
            url,
            created_at,
            seo_score,
            load_time,
            mobile_friendly,
            has_sitemap,
            meta_title_length,
            meta_description_length,
            h1_count,
            internal_links,
            external_links
        FROM crawl_results
        WHERE created_at > NOW() - INTERVAL '%s days'
        ORDER BY created_at DESC
        """
        return pd.read_sql(query, self.conn, params=[days])

    def calculate_statistics(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Calculate key statistics"""
        stats = {
            'total_crawls': len(df),
            'unique_urls': df['url'].nunique(),
            'avg_seo_score': df['seo_score'].mean(),
            'avg_load_time': df['load_time'].mean(),
            'mobile_friendly_pct': (df['mobile_friendly'].sum() / len(df)) * 100,
            'has_sitemap_pct': (df['has_sitemap'].sum() / len(df)) * 100,
            'avg_title_length': df['meta_title_length'].mean(),
            'avg_desc_length': df['meta_description_length'].mean()
        }
        return stats

    def find_correlations(self, df: pd.DataFrame) -> pd.DataFrame:
        """Find correlations between SEO factors"""
        numeric_cols = df.select_dtypes(include=[np.number]).columns
        return df[numeric_cols].corr()

    def identify_issues(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """Identify common SEO issues"""
        issues = []

        # Title length issues
        title_issues = df[
            (df['meta_title_length'] < 30) |
            (df['meta_title_length'] > 60)
        ]
        if len(title_issues) > 0:
            issues.append({
                'type': 'title_length',
                'severity': 'medium',
                'count': len(title_issues),
                'urls': title_issues['url'].tolist()[:5]
            })

        # Load time issues
        slow_pages = df[df['load_time'] > 3]
        if len(slow_pages) > 0:
            issues.append({
                'type': 'slow_load_time',
                'severity': 'high',
                'count': len(slow_pages),
                'urls': slow_pages['url'].tolist()[:5]
            })

        return issues

    def generate_insights(self, df: pd.DataFrame, stats: Dict) -> List[str]:
        """Generate actionable insights"""
        insights = []

        if stats['avg_load_time'] > 2:
            insights.append(f"Average load time ({stats['avg_load_time']:.2f}s) exceeds recommended 2s")

        if stats['mobile_friendly_pct'] < 90:
            insights.append(f"Only {stats['mobile_friendly_pct']:.1f}% of pages are mobile-friendly")

        if stats['has_sitemap_pct'] < 100:
            insights.append(f"{100 - stats['has_sitemap_pct']:.1f}% of sites missing sitemaps")

        return insights

    def create_visualizations(self, df: pd.DataFrame, output_dir: str = './'):
        """Create data visualizations"""
        plt.style.use('seaborn-v0_8')

        # SEO Score Distribution
        plt.figure(figsize=(10, 6))
        plt.hist(df['seo_score'], bins=20, edgecolor='black')
        plt.xlabel('SEO Score')
        plt.ylabel('Frequency')
        plt.title('SEO Score Distribution')
        plt.savefig(f'{output_dir}/seo_score_distribution.png')
        plt.close()

        # Load Time vs SEO Score
        plt.figure(figsize=(10, 6))
        plt.scatter(df['load_time'], df['seo_score'], alpha=0.5)
        plt.xlabel('Load Time (s)')
        plt.ylabel('SEO Score')
        plt.title('Load Time vs SEO Score')
        plt.savefig(f'{output_dir}/load_time_vs_seo_score.png')
        plt.close()

    def generate_report(self, output_file: str = 'seo_analysis_report.json'):
        """Generate comprehensive analysis report"""
        df = self.fetch_crawl_data()
        stats = self.calculate_statistics(df)
        correlations = self.find_correlations(df)
        issues = self.identify_issues(df)
        insights = self.generate_insights(df, stats)

        report = {
            'generated_at': datetime.now().isoformat(),
            'statistics': stats,
            'top_correlations': correlations.unstack().sort_values(ascending=False).head(10).to_dict(),
            'issues': issues,
            'insights': insights
        }

        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2, default=str)

        self.create_visualizations(df)

        return report

if __name__ == "__main__":
    import os

    # Get connection string from environment
    conn_str = os.getenv('DATABASE_URL')
    if not conn_str:
        print("Error: DATABASE_URL environment variable is required", file=sys.stderr)
        sys.exit(1)

    analyzer = SEODataAnalyzer(conn_str)
    report = analyzer.generate_report()

    print("Analysis complete!")
    print(f"Total crawls analyzed: {report['statistics']['total_crawls']}")
    print(f"Average SEO score: {report['statistics']['avg_seo_score']:.2f}")
    print("\nTop insights:")
    for insight in report['insights']:
        print(f"- {insight}")