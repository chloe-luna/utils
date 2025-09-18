#!/usr/bin/env python3
"""
Wikipedia Access Log Downloader

A command-line tool to download Wikipedia pageview logs from Wikimedia's public data dumps.
Supports downloading monthly pageview data with resume capability and parallel downloads.
"""

import argparse
import requests
import os
import sys
import gzip
import re
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import urljoin
from concurrent.futures import ThreadPoolExecutor, as_completed
import time


class WikiLogDownloader:
    def __init__(self, output_dir="./wiki_logs", max_workers=4, chunk_size=8192):
        self.base_url = "https://dumps.wikimedia.org/other/"
        self.pageviews_url = "https://dumps.wikimedia.org/other/pageviews/"
        self.pagecounts_ez_url = "https://dumps.wikimedia.org/other/pagecounts-ez/"
        self.output_dir = Path(output_dir)
        self.max_workers = max_workers
        self.chunk_size = chunk_size
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'WikiLogDownloader/1.0 (Educational/Research Purpose)'
        })
        
    def create_output_dir(self):
        """Create output directory if it doesn't exist."""
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def get_available_years_months(self, data_type="pageviews"):
        """Get list of available year/month combinations."""
        url = self.pageviews_url if data_type == "pageviews" else self.pagecounts_ez_url
        
        try:
            response = self.session.get(url)
            response.raise_for_status()
            
            # Parse HTML to find year directories
            year_pattern = r'<a href="(\d{4})/"'
            years = re.findall(year_pattern, response.text)
            
            available_periods = []
            for year in years:
                year_url = urljoin(url, f"{year}/")
                try:
                    year_response = self.session.get(year_url)
                    year_response.raise_for_status()
                    
                    # Find month directories (format: YYYY-MM)
                    month_pattern = rf'<a href="(\d{{4}}-\d{{2}})/"'
                    months = re.findall(month_pattern, year_response.text)
                    available_periods.extend(months)
                    
                except requests.RequestException as e:
                    print(f"Warning: Could not fetch months for year {year}: {e}")
                    
            return sorted(available_periods)
            
        except requests.RequestException as e:
            print(f"Error fetching available periods: {e}")
            return []
    
    def get_files_for_period(self, period, data_type="pageviews"):
        """Get list of files available for a specific period (YYYY-MM format)."""
        base_url = self.pageviews_url if data_type == "pageviews" else self.pagecounts_ez_url
        period_url = urljoin(base_url, f"{period}/")
        
        try:
            response = self.session.get(period_url)
            response.raise_for_status()
            
            if data_type == "pageviews":
                # Pageviews files are typically named: pageviews-YYYYMMDDHH.gz
                file_pattern = r'<a href="(pageviews-\d{10}\.gz)"'
            else:
                # Pagecounts-ez files have different naming
                file_pattern = r'<a href="(pagecounts-\d{8}\.bz2)"'
                
            files = re.findall(file_pattern, response.text)
            return files, period_url
            
        except requests.RequestException as e:
            print(f"Error fetching files for period {period}: {e}")
            return [], period_url
    
    def download_file(self, file_url, local_path, resume=True):
        """Download a single file with resume capability."""
        local_path = Path(local_path)
        
        # Check if file already exists and get its size
        resume_header = {}
        if resume and local_path.exists():
            existing_size = local_path.stat().st_size
            resume_header['Range'] = f'bytes={existing_size}-'
            mode = 'ab'
        else:
            mode = 'wb'
            existing_size = 0
        
        try:
            response = self.session.get(file_url, headers=resume_header, stream=True)
            
            # If resume was attempted but server doesn't support it
            if response.status_code == 416:  # Range Not Satisfiable
                print(f"File {local_path.name} already complete")
                return True
            elif response.status_code == 206:  # Partial Content
                print(f"Resuming download of {local_path.name} from byte {existing_size}")
            elif response.status_code == 200:
                if resume and existing_size > 0:
                    print(f"Server doesn't support resume, restarting {local_path.name}")
                    mode = 'wb'
                else:
                    print(f"Starting download of {local_path.name}")
            else:
                response.raise_for_status()
            
            # Get total file size
            content_length = response.headers.get('content-length')
            if content_length:
                total_size = int(content_length) + (existing_size if response.status_code == 206 else 0)
            else:
                total_size = None
            
            # Download with progress indication
            downloaded = existing_size
            with open(local_path, mode) as f:
                for chunk in response.iter_content(chunk_size=self.chunk_size):
                    if chunk:  # Filter out keep-alive chunks
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        # Simple progress indication
                        if total_size:
                            progress = (downloaded / total_size) * 100
                            print(f"\r{local_path.name}: {progress:.1f}% ({downloaded}/{total_size} bytes)", end='', flush=True)
                        else:
                            print(f"\r{local_path.name}: {downloaded} bytes downloaded", end='', flush=True)
            
            print(f"\n✓ Completed: {local_path.name}")
            return True
            
        except requests.RequestException as e:
            print(f"\n✗ Error downloading {local_path.name}: {e}")
            return False
        except IOError as e:
            print(f"\n✗ Error writing {local_path.name}: {e}")
            return False
    
    def download_period(self, period, data_type="pageviews", resume=True, max_files=None):
        """Download all files for a specific period."""
        print(f"\nFetching file list for {period}...")
        files, base_url = self.get_files_for_period(period, data_type)
        
        if not files:
            print(f"No files found for period {period}")
            return 0, 0
        
        if max_files:
            files = files[:max_files]
            
        print(f"Found {len(files)} files for {period}")
        
        # Create period-specific directory
        period_dir = self.output_dir / data_type / period
        period_dir.mkdir(parents=True, exist_ok=True)
        
        # Prepare download tasks
        download_tasks = []
        for filename in files:
            file_url = urljoin(base_url, filename)
            local_path = period_dir / filename
            download_tasks.append((file_url, local_path))
        
        # Download files using thread pool
        successful = 0
        failed = 0
        
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            future_to_task = {
                executor.submit(self.download_file, file_url, local_path, resume): (file_url, local_path)
                for file_url, local_path in download_tasks
            }
            
            for future in as_completed(future_to_task):
                file_url, local_path = future_to_task[future]
                try:
                    success = future.result()
                    if success:
                        successful += 1
                    else:
                        failed += 1
                except Exception as e:
                    print(f"Exception during download of {local_path.name}: {e}")
                    failed += 1
        
        print(f"\nPeriod {period} completed: {successful} successful, {failed} failed")
        return successful, failed
    
    def list_available_periods(self, data_type="pageviews"):
        """List all available periods."""
        print(f"Fetching available periods for {data_type}...")
        periods = self.get_available_years_months(data_type)
        
        if periods:
            print(f"\nAvailable periods ({len(periods)} total):")
            for i, period in enumerate(periods, 1):
                print(f"{i:3d}. {period}")
        else:
            print("No periods found or error occurred")
            
        return periods
    
    def validate_period_format(self, period):
        """Validate period format (YYYY-MM)."""
        pattern = r'^\d{4}-\d{2}$'
        return bool(re.match(pattern, period))


def main():
    parser = argparse.ArgumentParser(
        description="Download Wikipedia access logs from Wikimedia dumps",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --list                           # List available periods
  %(prog)s --period 2024-01                # Download January 2024 pageviews
  %(prog)s --period 2024-01 --type ez      # Download compressed format
  %(prog)s --period 2024-01 --max-files 10 # Download only first 10 files
  %(prog)s --period 2024-01 --workers 8    # Use 8 parallel downloads
        """
    )
    
    parser.add_argument('--list', '-l', action='store_true',
                       help='List available periods and exit')
    
    parser.add_argument('--period', '-p', type=str,
                       help='Period to download (format: YYYY-MM)')
    
    parser.add_argument('--type', '-t', choices=['pageviews', 'ez'], 
                       default='pageviews',
                       help='Data type: pageviews (default) or ez (compressed)')
    
    parser.add_argument('--output-dir', '-o', type=str, default='./wiki_logs',
                       help='Output directory (default: ./wiki_logs)')
    
    parser.add_argument('--workers', '-w', type=int, default=4,
                       help='Number of parallel downloads (default: 4)')
    
    parser.add_argument('--max-files', '-m', type=int,
                       help='Maximum number of files to download per period')
    
    parser.add_argument('--no-resume', action='store_true',
                       help='Disable resume functionality')
    
    parser.add_argument('--chunk-size', type=int, default=8192,
                       help='Chunk size for downloads in bytes (default: 8192)')
    
    args = parser.parse_args()
    
    # Create downloader instance
    downloader = WikiLogDownloader(
        output_dir=args.output_dir,
        max_workers=args.workers,
        chunk_size=args.chunk_size
    )
    downloader.create_output_dir()
    
    # Handle list command
    if args.list:
        data_type = 'pagecounts-ez' if args.type == 'ez' else 'pageviews'
        downloader.list_available_periods(data_type)
        return
    
    # Validate required arguments
    if not args.period:
        print("Error: --period is required (or use --list to see available periods)")
        sys.exit(1)
    
    if not downloader.validate_period_format(args.period):
        print("Error: Period must be in YYYY-MM format (e.g., 2024-01)")
        sys.exit(1)
    
    # Start download
    print(f"Wikipedia Log Downloader")
    print(f"Period: {args.period}")
    print(f"Type: {args.type}")
    print(f"Output: {args.output_dir}")
    print(f"Workers: {args.workers}")
    print(f"Resume: {'No' if args.no_resume else 'Yes'}")
    
    start_time = time.time()
    data_type = 'pagecounts-ez' if args.type == 'ez' else 'pageviews'
    
    successful, failed = downloader.download_period(
        args.period,
        data_type=data_type,
        resume=not args.no_resume,
        max_files=args.max_files
    )
    
    elapsed = time.time() - start_time
    print(f"\nDownload completed in {elapsed:.1f} seconds")
    print(f"Total: {successful} successful, {failed} failed")
    
    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
