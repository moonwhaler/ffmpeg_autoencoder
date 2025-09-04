# Advanced FFmpeg Multi-Mode Encoding Script Suite

A professional-grade Bash script suite for automated video encoding using FFmpeg with x265/HEVC codec. Features **multi-mode encoding support (CRF/ABR/CBR)**, intelligent content analysis, adaptive parameter optimization, automatic profile selection, and comprehensive batch processing capabilities.

## 🎯 Key Features

### Multi-Mode Encoding System
- **CRF Mode**: Single-pass Constant Rate Factor (Pure VBR) - Optimal for archival/mastering
- **ABR Mode**: Two-pass Average Bitrate (Default) - Perfect for streaming/delivery  
- **CBR Mode**: Two-pass Constant Bitrate - Essential for broadcast/live streaming

### Intelligent Content Analysis
- **Automatic Profile Selection**: AI-driven content classification with web search validation
- **Content-Aware Optimization**: Separate CRF and bitrate modifiers for different content types
- **Complexity Analysis**: Dynamic parameter adjustment based on video characteristics
- **HDR10 Detection**: Automatic HDR metadata preservation and parameter optimization

### Professional Features
- **Multi-Sample Crop Detection**: Temporal analysis across video timeline
- **Real-Time Progress Visualization**: Enhanced progress bars with ETA calculation
- **Comprehensive Logging**: Professional-grade logging with detailed parameter tracking
- **Batch Processing**: Directory-based encoding with UUID collision prevention

## 🚀 Quick Start

### Basic Usage
```bash
# Single file with automatic profile selection
./ffmpeg_encoder.sh -i video.mkv -p auto

# Batch processing entire directory
./ffmpeg_encoder.sh -i ~/Videos/ -p auto

# Specific profile with CRF mode for archival
./ffmpeg_encoder.sh -i movie.mkv -p 4k -m crf
```

## 📋 System Requirements

### Dependencies
- **ffmpeg** (with libx265 support)
- **ffprobe** (included with ffmpeg)
- **bc** (for floating-point calculations)
- **uuidgen** (for unique output naming)
- **jq** (for JSON processing in auto-selection)

### Installation
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install ffmpeg bc uuid-runtime jq

# macOS (Homebrew)
brew install ffmpeg bc jq
```

## 🎬 Encoding Profiles

The system includes 6 meticulously optimized profiles for different content types:

### Available Profiles

| Profile | Content Type | Base CRF | Optimization Focus |
|---------|--------------|----------|-------------------|
| **`anime`** | 2D Animation | 23 | Flat areas, enhanced deblocking, animation tuning |
| **`classic_anime`** | Classic Animation | 22 | Film grain preservation, finer detail retention |
| **`3d_cgi`** | 3D CGI (Pixar-like) | 22 | Complex textures, smooth gradients, detail preservation |
| **`3d_complex`** | Complex 3D (Arcane-like) | 21 | High detail, complex animation, enhanced parameters |
| **`4k`** | General 4K Content | 22 | Balanced general-purpose optimization |
| **`4k_heavy_grain`** | Heavy Grain 4K | 21 | Specialized grain preservation, selective SAO |

## 🎛️ Encoding Modes

### Mode Comparison

| Mode | Passes | Quality Control | File Size | Best For | Technical Notes |
|------|--------|-----------------|-----------|-----------|-----------------| 
| **CRF** | 1 | Pure quality-based | Variable | Archival, Mastering | Single-pass VBR, no bitrate constraints |
| **ABR** | 2 | Quality + size balance | Predictable | Streaming, VOD | Fast first pass, quality second pass |
| **CBR** | 2 | Constant bandwidth | Constant | Broadcast, Live | VBV buffer constraints for constant rate |

### Technical Implementation Details

**CRF Mode (Pure Variable Bitrate)**:
```bash
# Single-pass encoding with quality-based rate control
ffmpeg -i input.mkv -c:v libx265 \
    -crf [adaptive_crf] -preset slow \
    -x265-params "[profile_params]" \
    output.mkv

# Bitrate parameters completely removed for pure VBR
# CRF adapts based on content type and complexity analysis
```

**ABR Mode (Two-Pass Average Bitrate)**:
```bash
# Pass 1: Fast statistical analysis
ffmpeg -i input.mkv -c:v libx265 \
    -b:v [adaptive_bitrate] -pass 1 \
    -preset medium -x265-params "no-slow-firstpass=1" \
    -f null /dev/null

# Pass 2: Quality-optimized encoding
ffmpeg -i input.mkv -c:v libx265 \
    -b:v [adaptive_bitrate] -pass 2 \
    -preset slow -x265-params "[profile_params]" \
    output.mkv
```

**CBR Mode (Constant Bitrate)**:
```bash
# Two-pass with VBV buffer rate control
ffmpeg -i input.mkv -c:v libx265 \
    -b:v [bitrate] -minrate [bitrate] -maxrate [bitrate] \
    -bufsize [1.5x bitrate] -pass 1/2 \
    -x265-params "[profile_params]" \
    output.mkv

# Buffer size = 1.5x target bitrate for stable rate control
```

## 🤖 Automatic Profile Selection

### Intelligent Content Classification

The system uses multi-layer analysis:

1. **Technical Analysis**: Resolution, grain level, motion complexity
2. **Web Search Validation**: Title extraction and content verification
3. **Confidence Scoring**: Combines technical and web search results

### Usage Examples

```bash
# Auto-selection with web search (default)
./ffmpeg_encoder.sh -i "Spirited Away (2001).mkv" -p auto

# Force web search even with high technical confidence  
./ffmpeg_encoder.sh -i movie.mkv -p auto --web-search-force

# Disable web search, use technical analysis only
./ffmpeg_encoder.sh -i movie.mkv -p auto --no-web-search
```

## 📊 Content Analysis Features

### Complexity Analysis System

When enabled with `--use-complexity`, the system analyzes:

- **Spatial Information (SI)**: Edge density and texture complexity
- **Temporal Information (TI)**: Motion and scene change analysis  
- **Grain Detection**: Multi-sample grain pattern analysis
- **Frame Distribution**: I/P/B frame complexity assessment

### Adaptive Parameter Calculation

```bash
# Content-aware CRF adjustment
final_crf = base_crf + content_modifier + complexity_adjustment

Content Modifiers:
- Anime: +0.2 CRF (efficient for flat areas)
- 3D Animation: -0.4 CRF (preserve CGI detail)  
- Film: 0.0 CRF (baseline for live-action)

# Dynamic bitrate scaling
complexity_factor = 0.7 + (complexity_score / 100 × 0.6)
adaptive_bitrate = base_bitrate × complexity_factor × content_modifier
```

## 🎥 Usage Examples

### Content-Specific Encoding

**Modern Anime**:
```bash
# CRF for archival quality
./ffmpeg_encoder.sh -i anime.mkv -p anime -m crf

# ABR for streaming with complexity analysis
./ffmpeg_encoder.sh -i anime.mkv -p anime -m abr --use-complexity
```

**3D Animation/CGI**:
```bash
# Preserve rendering detail
./ffmpeg_encoder.sh -i pixar_movie.mkv -p 3d_cgi -m crf

# Complex animation (Arcane-style)
./ffmpeg_encoder.sh -i arcane.mkv -p 3d_complex -m abr
```

**Live-Action Film**:
```bash
# General 4K film
./ffmpeg_encoder.sh -i film.mkv -p 4k -m abr

# Heavy grain preservation
./ffmpeg_encoder.sh -i grain_film.mkv -p 4k_heavy_grain -m crf --denoise
```

### Advanced Options

```bash
# Full feature demonstration
./ffmpeg_encoder.sh \
  -i input.mkv \
  -o custom_output.mkv \
  -p auto \
  -m crf \
  -t "Movie Title" \
  --use-complexity \
  --denoise \
  --hardware
```

## 📁 Batch Processing

### Simplified Batch Workflow

Process entire directories with consistent naming:

```bash
# Process all videos in directory with auto-selection
./ffmpeg_encoder.sh -i ~/Videos/Raw/ -p auto -m abr

# All files encoded in same directory with UUID-based names:
# input_a1b2c3d4-e5f6-7890-abcd-ef1234567890.mkv
```

### Key Batch Features

- **Recursive Processing**: Handles nested directory structures
- **UUID-Based Naming**: Prevents file overwrites automatically  
- **Format Support**: .mkv, .mp4, .mov, .m4v files
- **Progress Tracking**: Individual file progress with batch overview

## 🛠️ Command Line Reference

### Required Parameters
- **`-i, --input`**: Input file or directory
- **`-p, --profile`**: Encoding profile (or 'auto' for intelligent selection)

### Optional Parameters
- **`-o, --output`**: Output filename (defaults to input_UUID.ext)
- **`-m, --mode`**: Encoding mode: crf, abr, cbr (default: abr)
- **`-t, --title`**: Video title metadata
- **`-c, --crop`**: Manual crop override (w:h:x:y format)  
- **`-s, --scale`**: Scale resolution (w:h format)

### Advanced Options
- **`--use-complexity`**: Enable adaptive parameter optimization
- **`--denoise`**: Apply light denoising (hqdn3d=1:1:2:2)
- **`--hardware`**: Enable CUDA acceleration (with fallback)
- **`--web-search`**: Enable web search validation (default)
- **`--web-search-force`**: Force web search even with high confidence
- **`--no-web-search`**: Disable web search, use technical analysis only

## 📈 Progress Visualization

### Real-Time Monitoring

The system provides comprehensive progress tracking:

```
CRF Encoding (Single Pass): [████████████████████████████████████░░░] 72.3% | ETA: 04:27 | Est: 2.1GB
ABR First Pass (Analysis):  [██████████████████████████████████████] 100.0% | Completed
ABR Second Pass (Final):    [██████████████████████████░░░░░░░░░░░░░] 65.8% | ETA: 06:15 | Est: 1.8GB
```

### Logging System

- **Color-coded output**: INFO (green), WARN (yellow), ERROR (red), ANALYSIS (purple)
- **Detailed parameter logging**: Complexity scores, adaptive adjustments
- **Comprehensive session logs**: Saved alongside output files

## 🔧 Advanced Features

### HDR10 Support

Automatic HDR detection and handling:

- **Color space preservation**: BT.2020 with SMPTE2084 transfer
- **Metadata passthrough**: Master Display and Content Light Level info
- **Adaptive parameters**: +2 CRF and +20% bitrate for HDR content

### Automatic Crop Detection

Multi-temporal analysis system:

- **Sample points**: Beginning (60s), middle, end (duration-60s)
- **HDR-adaptive thresholds**: Different limits for HDR vs SDR
- **Validation logic**: Only applies significant crops (>1% change)

### Stream Preservation

Comprehensive stream handling:

- **Lossless audio copy**: All audio tracks preserved without transcoding
- **Subtitle preservation**: All subtitle formats and languages maintained  
- **Chapter & metadata**: Navigation and metadata information transferred

## 💡 Professional Use Cases

### Content Production Workflows

**Archival & Mastering**:
```bash
# Maximum quality preservation
./ffmpeg_encoder.sh -i master.mkv -p auto -m crf --use-complexity
```

**Streaming Preparation**:
```bash  
# Predictable sizes for adaptive streaming
./ffmpeg_encoder.sh -i content.mkv -p auto -m abr --use-complexity
```

**Broadcast Delivery**:
```bash
# Constant bitrate for transmission
./ffmpeg_encoder.sh -i broadcast.mkv -p 4k -m cbr
```

### Performance Recommendations

| Content Type | Best Mode | Profile Recommendation | Special Flags |
|--------------|-----------|----------------------|---------------|
| **Anime Archive** | CRF | anime/classic_anime | --use-complexity |
| **3D Animation Master** | CRF | 3d_cgi/3d_complex | --use-complexity |
| **Streaming VOD** | ABR | auto | --use-complexity |
| **Live Broadcast** | CBR | appropriate for content | minimal flags |
| **Heavy Grain Film** | CRF | 4k_heavy_grain | --denoise optional |

## 🚨 Troubleshooting

### Common Issues

**Encoding fails with error**:
- Check ffmpeg installation: `ffmpeg -version`
- Verify input file: `ffprobe input.mkv`
- Review error logs in generated .log file

**Slow encoding performance**:
- Use hardware acceleration: `--hardware`
- Choose appropriate preset for content type
- Consider ABR mode over CRF for production workflows

**Unexpected file sizes**:
- Enable complexity analysis: `--use-complexity`
- Check HDR detection in logs
- Review adaptive parameter calculations

## 🏆 Quality Metrics

### Encoding Efficiency
- **50-70% size reduction** vs x264 at equivalent quality
- **Content-adaptive savings**: Up to 30% additional optimization
- **Mode-specific tuning**: Each mode optimized for its use case

### Quality Preservation
- **10-bit encoding**: Prevents color banding across all profiles
- **HDR metadata integrity**: Lossless HDR10 passthrough  
- **Stream preservation**: Zero-loss audio/subtitle copying
- **Content-aware optimization**: Optimal parameters per content type

---

## 📄 Version Information

**Current Version**: 2.4  
**Last Updated**: January 2025  
**Compatibility**: FFmpeg 4.0+, x265 3.0+

This script suite represents **state-of-the-art automated video encoding** with professional-grade multi-mode support, suitable for individual creators, streaming platforms, broadcast facilities, and enterprise media workflows.