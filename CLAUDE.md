# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview
A professional Bash script suite for automated video encoding using FFmpeg with x265/HEVC codec. The system provides **multi-mode encoding support (CRF/ABR/CBR)**, content-adaptive encoding with automated analysis, and batch processing capabilities.

## Core Scripts Architecture

### `ffmpeg_encoder.sh` - Multi-Mode Encoding Engine
- **Multi-Mode Support**: CRF (single-pass VBR), ABR (two-pass average bitrate), CBR (two-pass constant bitrate)
- **Content Analysis Engine**: Implements Spatial Information (SI), Temporal Information (TI), Scene Change Detection, and Frame Distribution analysis
- **Dual-Aware Optimization**: Content-type AND complexity-based parameter adjustment
- **Content-Aware CRF**: Separate CRF modifiers for Anime (+0.5), 3D Animation (-0.8), Film (0.0)
- **Adaptive Bitrate Optimization**: Dynamically adjusts bitrates by ±40% based on content complexity scoring
- **Automatic Crop Detection**: Multi-sample analysis across video timeline with frequency-based selection
- **HDR10 Support**: Automatic detection and metadata preservation for HDR content
- **Progress Visualization**: Real-time progress bars and spinners for all encoding phases

### `ffmpeg_batch_encoder.sh` - Batch Processing Wrapper  
- Processes all video files recursively in input directory
- **Mode Support**: All three encoding modes supported in batch processing
- Uses UUID-based naming to prevent file overwrites
- Supports .mkv, .mp4, .mov, .m4v formats

## Multi-Mode Encoding System

### **3 Professional Encoding Modes**
- **`CRF Mode (-m crf)`**: Single-pass Constant Rate Factor (Pure VBR) - Best for archival/mastering
- **`ABR Mode (-m abr)`**: Two-pass Average Bitrate (Default) - Best for streaming/delivery  
- **`CBR Mode (-m cbr)`**: Two-pass Constant Bitrate - Best for broadcast/live streaming

### **Mode Selection Guide**
| Mode | Use Case | Quality | File Size | Bandwidth |
|------|----------|---------|-----------|-----------|
| **CRF** | Archival, Mastering | Highest | Variable | Variable |
| **ABR** | Streaming, VOD | High | Predictable | Variable |
| **CBR** | Broadcast, Live | Good | Predictable | Constant |

## Encoding Profiles
12 optimized profiles available:
- **1080p profiles**: `1080p_anime`, `1080p_anime_hdr`, `1080p_3d_animation`, `1080p_3d_animation_hdr`, `1080p_film`, `1080p_film_hdr`
- **4K profiles**: `4k_anime`, `4k_anime_hdr`, `4k_3d_animation`, `4k_3d_animation_hdr`, `4k_film`, `4k_film_hdr`

Each profile includes content-type specific optimizations:
- **Anime**: Enhanced deblocking, animation tuning (-15% bitrate modifier, +0.5 CRF modifier)
- **3D Animation**: CGI-optimized parameters (+10% bitrate modifier, -0.8 CRF modifier)  
- **Film**: Balanced live-action optimization (baseline bitrate, 0.0 CRF modifier)

## Common Commands

### Single File Encoding with Modes

**CRF Mode (Quality-Based, Variable Size):**
```bash
./ffmpeg_encoder.sh -i input.mkv -o output.mkv -p 1080p_anime -m crf
./ffmpeg_encoder.sh -i input.mp4 -o output.mp4 -p 4k_film_hdr -m crf -t "Movie Title"
./ffmpeg_encoder.sh -i cgi_movie.mkv -o output.mkv -p 1080p_3d_animation -m crf
```

**ABR Mode (Streaming/Delivery, Predictable Size):**
```bash
./ffmpeg_encoder.sh -i input.mkv -o output.mkv -p 1080p_anime -m abr
./ffmpeg_encoder.sh -i input.mp4 -o output.mp4 -p 4k_film_hdr -m abr -t "Movie Title"
./ffmpeg_encoder.sh -i input.mkv -o output.mkv -p 1080p_film -m abr -c 1920:800:0:140
```

**CBR Mode (Broadcast/Live, Constant Bitrate):**
```bash
./ffmpeg_encoder.sh -i input.mkv -o output.mkv -p 1080p_anime -m cbr
./ffmpeg_encoder.sh -i broadcast.mkv -o output.mkv -p 1080p_film -m cbr
```

**Default Mode (ABR if not specified):**
```bash
./ffmpeg_encoder.sh -i input.mkv -o output.mkv -p 1080p_anime
# Equivalent to: ./ffmpeg_encoder.sh -i input.mkv -o output.mkv -p 1080p_anime -m abr
```

### Batch Processing with Modes
```bash
# CRF batch processing for archival
./ffmpeg_batch_encoder.sh -i ~/Videos/Raw -o ~/Videos/Archive -p 1080p_anime -m crf

# ABR batch processing for streaming (default)
./ffmpeg_batch_encoder.sh -i ~/Videos/Raw -o ~/Videos/Stream -p 1080p_anime -m abr

# CBR batch processing for broadcast
./ffmpeg_batch_encoder.sh -i ~/Videos/Raw -o ~/Videos/Broadcast -p 1080p_film -m cbr
```

### View Available Profiles and Modes
```bash
./ffmpeg_encoder.sh --help
```

## Technical Implementation Details

### Multi-Mode Encoding Strategy

**CRF Mode (Single-Pass VBR):**
- Single pass encoding using only CRF value
- No bitrate constraints applied
- Pure quality-based encoding
- Command: `ffmpeg -i input -crf [adaptive_crf] -preset slow output`

**ABR Mode (Two-Pass Average Bitrate):**
- Pass 1: Uses `medium` preset for fast analysis with `no-slow-firstpass=1`
- Pass 2: Uses profile-defined preset (`slow` for 1080p, `medium` for 4K)
- Uses adaptive bitrate as target
- Temporary stats files stored in `/tmp` with process-ID suffix

**CBR Mode (Two-Pass Constant Bitrate):**
- Pass 1: Statistical analysis with buffer constraints
- Pass 2: Constant bitrate encoding with VBV buffer
- Buffer size: 1.5x target bitrate
- Uses `-minrate`, `-maxrate`, and `-bufsize` for constant output

### Complexity Analysis Algorithm
Content complexity score calculated from:
```
complexity_score = (SI × 0.3) + (TI × 0.4) + (scene_changes × 2) + (frame_complexity × 0.3)
```

### Dual-Aware Parameter Calculation

**Content-Aware CRF Adjustment:**
```
final_crf = base_crf + content_type_modifier + complexity_adjustment

Content Type Modifiers:
- Anime: +0.5 CRF (efficient compression for flat areas)
- 3D Animation: -0.8 CRF (preserve CGI detail and textures)
- Film: 0.0 CRF (balanced live-action optimization)

Complexity Adjustment: (complexity_score - 50) × (-0.05)
```

**Adaptive Bitrate Calculation:**
```
complexity_factor = 0.7 + (complexity_score / 100 × 0.6)
adaptive_bitrate = base_bitrate × complexity_factor × content_modifier

Content Type Modifiers:
- Anime: 0.85 (-15% bitrate)
- 3D Animation: 1.1 (+10% bitrate)
- Film: 1.0 (baseline bitrate)
```

### Mode-Specific Parameter Usage

| Mode | Uses CRF | Uses Bitrate | Passes | Quality Control |
|------|----------|--------------|---------|-----------------|
| **CRF** | ✅ Adaptive CRF only | ❌ Ignored | 1 | Pure quality-based |
| **ABR** | ✅ For quality estimation | ✅ Adaptive bitrate | 2 | Quality + size balance |
| **CBR** | ✅ For quality estimation | ✅ + buffer constraints | 2 | Constant bandwidth |

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
- **Mode-specific progress messages**: "CRF Encoding (Single Pass)", "ABR First Pass (Analysis)", "CBR Second Pass (Final Encoding)"

## Stream Preservation
- **Lossless audio copy**: 1:1 copy of all audio streams without transcoding
- **Subtitle preservation**: Maintains all subtitle formats and languages  
- **Chapter & metadata transfer**: Preserves navigation and metadata information
- **Automatic stream detection**: Dynamic stream mapping via ffprobe analysis

## HDR Processing
- Automatic HDR10 detection via color primaries and transfer characteristics
- Metadata preservation including Master Display and Content Light Level information
- Correct BT.2020 color space implementation with SMPTE2084 transfer curves
- **Content-aware HDR handling**: +2 CRF and +20% bitrate for HDR content

## Content Type Recommendations

### **Anime/2D Animation**
- **Recommended Profile**: `1080p_anime` or `4k_anime`
- **Best Mode**: `CRF` (archival) or `ABR` (streaming)
- **Reasoning**: Flat areas compress efficiently, +0.5 CRF modifier accounts for animation characteristics

### **3D Animation/CGI**  
- **Recommended Profile**: `1080p_3d_animation` or `4k_3d_animation`
- **Best Mode**: `CRF` (preserve detail) 
- **Reasoning**: CGI needs detail preservation, -0.8 CRF modifier for rendering quality

### **Live-Action Film**
- **Recommended Profile**: `1080p_film` or `4k_film`  
- **Best Mode**: `ABR` (streaming) or `CBR` (broadcast)
- **Reasoning**: Balanced approach with 0.0 CRF modifier for natural content

### **Professional Use Cases**
- **Archival/Master**: Use `CRF` mode with highest quality profile
- **Streaming/VOD**: Use `ABR` mode for predictable file sizes
- **Broadcast/Live**: Use `CBR` mode for constant bandwidth requirements

## Important Notes for Claude Code Users

When working with this codebase, remember:
1. **Mode parameter is optional** - defaults to `abr` if not specified
2. **All existing features work in all modes** - crop detection, HDR support, stream preservation
3. **Content-type awareness affects both CRF and bitrate** in all modes
4. **CRF mode ignores bitrate completely** - uses only quality-based encoding
5. **CBR mode adds buffer constraints** for constant bitrate output
6. **Complexity analysis runs for all modes** - provides adaptive parameter optimization