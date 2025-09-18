#!/usr/bin/env python3
"""
Offline Framework Downloader
Downloads GitHub repositories for offline development and study.
"""

import os
import sys
import subprocess
import argparse
import logging
from pathlib import Path
from urllib.parse import urlparse
import time

class FrameworkDownloader:
    def __init__(self, base_dir="offline_frameworks", log_level=logging.INFO):
        self.base_dir = Path(base_dir)
        self.base_dir.mkdir(exist_ok=True)
        
        # Setup logging
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.base_dir / 'download.log'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
        
        # Statistics
        self.stats = {
            'total': 0,
            'success': 0,
            'failed': 0,
            'skipped': 0
        }

    def parse_github_url(self, url):
        """Extract owner and repo name from GitHub URL"""
        try:
            # Handle different URL formats
            if url.startswith('git@github.com:'):
                # SSH format: git@github.com:owner/repo.git
                parts = url.replace('git@github.com:', '').replace('.git', '').split('/')
                return parts[0], parts[1]
            elif 'github.com' in url:
                # HTTPS format: https://github.com/owner/repo
                parsed = urlparse(url)
                path_parts = parsed.path.strip('/').split('/')
                if len(path_parts) >= 2:
                    return path_parts[0], path_parts[1].replace('.git', '')
            
            return None, None
        except Exception as e:
            self.logger.error(f"Error parsing URL {url}: {e}")
            return None, None

    def clone_repository(self, url, target_dir):
        """Clone a single repository"""
        try:
            # Use git clone with --depth 1 for faster downloads (latest commit only)
            # Remove --depth 1 if you need full history
            cmd = [
                'git', 'clone', 
                '--depth', '1',  # Remove this line if you need full git history
                url, 
                str(target_dir)
            ]
            
            self.logger.info(f"Cloning {url} to {target_dir}")
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout per repo
            )
            
            if result.returncode == 0:
                self.logger.info(f"✓ Successfully cloned {url}")
                return True
            else:
                self.logger.error(f"✗ Failed to clone {url}: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            self.logger.error(f"✗ Timeout cloning {url}")
            return False
        except Exception as e:
            self.logger.error(f"✗ Error cloning {url}: {e}")
            return False

    def download_from_file(self, repo_file, framework_name=None):
        """Download all repositories listed in a file"""
        repo_file = Path(repo_file)
        if not repo_file.exists():
            self.logger.error(f"Repository file {repo_file} does not exist")
            return False

        # Create framework directory
        if framework_name:
            framework_dir = self.base_dir / framework_name
        else:
            framework_dir = self.base_dir / repo_file.stem
        
        framework_dir.mkdir(exist_ok=True)
        
        self.logger.info(f"Starting download to {framework_dir}")
        self.logger.info(f"Reading repositories from {repo_file}")
        
        with open(repo_file, 'r') as f:
            urls = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        
        self.stats['total'] = len(urls)
        self.logger.info(f"Found {len(urls)} repositories to download")
        
        for i, url in enumerate(urls, 1):
            self.logger.info(f"Processing {i}/{len(urls)}: {url}")
            
            owner, repo = self.parse_github_url(url)
            if not owner or not repo:
                self.logger.warning(f"Skipping invalid URL: {url}")
                self.stats['skipped'] += 1
                continue
            
            # Create target directory
            repo_dir = framework_dir / f"{owner}_{repo}"
            
            # Skip if already exists
            if repo_dir.exists():
                self.logger.info(f"Repository {repo_dir.name} already exists, skipping")
                self.stats['skipped'] += 1
                continue
            
            # Clone repository
            if self.clone_repository(url, repo_dir):
                self.stats['success'] += 1
            else:
                self.stats['failed'] += 1
                # Clean up partial clone
                if repo_dir.exists():
                    import shutil
                    shutil.rmtree(repo_dir)
            
            # Small delay to be respectful to GitHub
            time.sleep(0.5)
        
        self.print_stats()
        return True

    def print_stats(self):
        """Print download statistics"""
        self.logger.info("=" * 50)
        self.logger.info("DOWNLOAD SUMMARY")
        self.logger.info("=" * 50)
        self.logger.info(f"Total repositories: {self.stats['total']}")
        self.logger.info(f"Successfully downloaded: {self.stats['success']}")
        self.logger.info(f"Failed: {self.stats['failed']}")
        self.logger.info(f"Skipped: {self.stats['skipped']}")
        self.logger.info("=" * 50)

    def create_sample_repo_file(self, filename, framework="kubernetes"):
        """Create a sample repository file for common frameworks"""
        
        sample_repos = {
            "kubernetes": [
                "# Kubernetes Core",
                "https://github.com/kubernetes/kubernetes",
                "https://github.com/kubernetes/kubectl",
                "https://github.com/kubernetes/client-go",
                "https://github.com/kubernetes/api",
                "https://github.com/kubernetes/apimachinery",
                "",
                "# Popular Kubernetes Tools",
                "https://github.com/helm/helm",
                "https://github.com/istio/istio",
                "https://github.com/prometheus/prometheus",
                "https://github.com/grafana/grafana",
                "https://github.com/kubernetes/ingress-nginx",
                "https://github.com/cert-manager/cert-manager",
                "",
                "# CNI Plugins",
                "https://github.com/containernetworking/cni",
                "https://github.com/containernetworking/plugins",
                "https://github.com/flannel-io/flannel",
                "https://github.com/projectcalico/calico",
                "",
                "# Storage",
                "https://github.com/kubernetes-csi/external-provisioner",
                "https://github.com/rook/rook"
            ],
            "react": [
                "# React Core",
                "https://github.com/facebook/react",
                "https://github.com/facebook/create-react-app",
                "",
                "# Popular React Libraries",
                "https://github.com/reduxjs/redux",
                "https://github.com/reactjs/react-router",
                "https://github.com/styled-components/styled-components",
                "https://github.com/mui/material-ui",
                "https://github.com/chakra-ui/chakra-ui"
            ],
            "django": [
                "# Django Core",
                "https://github.com/django/django",
                "",
                "# Popular Django Packages",
                "https://github.com/django/channels",
                "https://github.com/encode/django-rest-framework",
                "https://github.com/jazzband/django-debug-toolbar",
                "https://github.com/django/django-contrib-comments"
            ]
        }
        
        repos = sample_repos.get(framework, [f"# Add {framework} repositories here"])
        
        with open(filename, 'w') as f:
            f.write('\n'.join(repos))
        
        print(f"Created sample repository file: {filename}")
        print(f"Edit this file to add or remove repositories for {framework}")

def main():
    parser = argparse.ArgumentParser(
        description="Download GitHub repositories for offline development",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Create a sample Kubernetes repo list
  python downloader.py --create-sample kubernetes_repos.txt --framework kubernetes
  
  # Download all repos from the file
  python downloader.py kubernetes_repos.txt
  
  # Download with custom framework name and directory
  python downloader.py kubernetes_repos.txt --framework k8s --output my_downloads
        """
    )
    
    parser.add_argument('repo_file', nargs='?', help='File containing GitHub repository URLs (one per line)')
    parser.add_argument('--framework', '-f', help='Framework name (used for directory organization)')
    parser.add_argument('--output', '-o', default='offline_frameworks', help='Output directory (default: offline_frameworks)')
    parser.add_argument('--create-sample', help='Create a sample repository file with given name')
    parser.add_argument('--sample-framework', default='kubernetes', choices=['kubernetes', 'react', 'django'],
                       help='Framework for sample file (default: kubernetes)')
    parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Create sample file if requested
    if args.create_sample:
        downloader = FrameworkDownloader()
        downloader.create_sample_repo_file(args.create_sample, args.sample_framework)
        return
    
    # Require repo file for download
    if not args.repo_file:
        parser.print_help()
        return
    
    # Check if git is available
    try:
        subprocess.run(['git', '--version'], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Error: Git is not installed or not in PATH")
        print("Please install Git first: https://git-scm.com/")
        return
    
    # Create downloader and start download
    log_level = logging.DEBUG if args.verbose else logging.INFO
    downloader = FrameworkDownloader(args.output, log_level)
    
    try:
        downloader.download_from_file(args.repo_file, args.framework)
    except KeyboardInterrupt:
        print("\nDownload interrupted by user")
        downloader.print_stats()
    except Exception as e:
        print(f"Error during download: {e}")
        downloader.print_stats()

if __name__ == "__main__":
    main()
