# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview
A professional Bash script suite for automated video encoding using FFmpeg with x265/HEVC codec. The system provides content-adaptive encoding with automated analysis and batch processing capabilities.

## Core Scripts Architecture

### `ffmpeg_encoder.sh` - Main Encoding Engine
- **Content Analysis Engine**: Implements Spatial Information (SI), Temporal Information (TI), Scene Change Detection, and Frame Distribution analysis
- **Adaptive Bitrate Optimization**: Dynamically adjusts bitrates by ±40% based on content complexity scoring
- **Automatic Crop Detection**: Multi-sample analysis across video timeline with frequency-based selection
- **HDR10 Support**: Automatic detection and metadata preservation for HDR content
- **Progress Visualization**: Real-time progress bars and spinners for all encoding phases

### `ffmpeg_batch_encoder.sh` - Batch Processing Wrapper  
- Processes all video files recursively in input directory
- Uses UUID-based naming to prevent file overwrites
- Supports .mkv, .mp4, .mov, .m4v formats

## Encoding Profiles
12 optimized profiles available:
- **1080p profiles**: `1080p_anime`, `1080p_anime_hdr`, `1080p_3d_animation`, `1080p_3d_animation_hdr`, `1080p_film`, `1080p_film_hdr`
- **4K profiles**: `4k_anime`, `4k_anime_hdr`, `4k_3d_animation`, `4k_3d_animation_hdr`, `4k_film`, `4k_film_hdr`

Each profile includes content-type specific optimizations:
- **Anime**: Enhanced deblocking, animation tuning (-15% bitrate modifier)
- **3D Animation**: CGI-optimized parameters (+10% bitrate modifier)  
- **Film**: Balanced live-action optimization (baseline bitrate)

## Common Commands

### Single File Encoding
```bash
./ffmpeg_encoder.sh -i input.mkv -o output.mkv -p 1080p_anime
./ffmpeg_encoder.sh -i input.mp4 -o output.mp4 -p 4k_film_hdr -t "Movie Title"
./ffmpeg_encoder.sh -i input.mkv -o output.mkv -p 1080p_film -c 1920:800:0:140
```

### Batch Processing
```bash
./ffmpeg_batch_encoder.sh -i ~/Videos/Raw -o ~/Videos/Encoded -p 1080p_anime
```

### View Available Profiles
```bash
./ffmpeg_encoder.sh --help
```

## Technical Implementation Details

### Two-Pass Encoding Strategy
- Pass 1: Uses `medium` preset for fast analysis with `no-slow-firstpass=1`
- Pass 2: Uses profile-defined preset (`slow` for 1080p, `medium` for 4K)
- Temporary stats files stored in `/tmp` with process-ID suffix

### Complexity Analysis Algorithm
Content complexity score calculated from:
```
complexity_score = (SI × 0.3) + (TI × 0.4) + (scene_changes × 2) + (frame_complexity × 0.3)
```

### Adaptive Parameter Calculation
```
complexity_factor = 0.7 + (complexity_score / 100 × 0.6)
adaptive_bitrate = base_bitrate × complexity_factor × content_modifier
adaptive_crf = base_crf + ((complexity_score - 50) × -0.05)
```

## Dependencies
- `ffmpeg` with libx265 support and advanced filters
- `ffprobe` for stream analysis and metadata extraction  
- `bc` for floating-point arithmetic calculations
- `uuidgen` for batch processing unique file names

## Progress Visualization System
Scripts include sophisticated progress tracking:
- **Real-time progress bars** for encoding phases with time/percentage display
- **Spinner animations** for analysis phases of unknown duration
- **Color-coded logging** with timestamp formatting (INFO/WARN/ERROR/DEBUG/ANALYSIS/CROP)

## Stream Preservation
- **Lossless audio copy**: 1:1 copy of all audio streams without transcoding
- **Subtitle preservation**: Maintains all subtitle formats and languages  
- **Chapter & metadata transfer**: Preserves navigation and metadata information
- **Automatic stream detection**: Dynamic stream mapping via ffprobe analysis

## HDR Processing
- Automatic HDR10 detection via color primaries and transfer characteristics
- Metadata preservation including Master Display and Content Light Level information
- Correct BT.2020 color space implementation with SMPTE2084 transfer curves