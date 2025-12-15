# Downloading Kiwix ZIM Files

## Browse Available ZIMs

**Main Index**: https://download.kiwix.org/zim/

Browse by category to find the ZIM files you want:
- [Wikipedia](https://download.kiwix.org/zim/wikipedia/)
- [Wiktionary](https://download.kiwix.org/zim/wiktionary/)
- [Wikibooks](https://download.kiwix.org/zim/wikibooks/)
- [Wikivoyage](https://download.kiwix.org/zim/wikivoyage/)
- [Wikiquote](https://download.kiwix.org/zim/wikiquote/)
- [Stack Exchange](https://download.kiwix.org/zim/stack_exchange/)
- [Project Gutenberg](https://download.kiwix.org/zim/gutenberg/)
- [TED](https://download.kiwix.org/zim/ted/)
- [Vikidia](https://download.kiwix.org/zim/vikidia/)
- [FreeCodeCamp](https://download.kiwix.org/zim/freecodecamp/)
- [iFixit](https://download.kiwix.org/zim/ifixit/)
- [And more...](https://download.kiwix.org/zim/)

## Quick Download Script

Use the provided script to download ZIMs:

```bash
cd ~/services/offline-wiki
chmod +x download-zims.sh

# Download a ZIM (auto-detects category)
./download-zims.sh wikipedia_en_all_maxi_2025-08.zim

# Or specify category explicitly
./download-zims.sh wikipedia_en_all_maxi_2025-08.zim wikipedia
```

## Manual Download

If you prefer to download manually:

```bash
cd /mnt/storage/kiwix/zims

# Download with resume support
wget -c "https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_maxi_2025-08.zim"
```

## After Downloading

1. **Rebuild the library**:
   ```bash
   cd ~/services/offline-wiki
   ./scripts/add_zims.sh
   ```

2. **Library auto-reloads** - No container restart needed! (The `-M` flag enables automatic library monitoring)

## Popular ZIM Files

### Wikipedia Variants
- `wikipedia_en_all_maxi_YYYY-MM.zim` - Full Wikipedia with images (~100GB+)
- `wikipedia_en_all_nopic_YYYY-MM.zim` - Text-only Wikipedia (~40GB)
- `wikipedia_en_top_YYYY-MM.zim` - Top articles only (~5GB)

### Other Content
- `wiktionary_en_all_nopic_YYYY-MM.zim` - Dictionary (text-only)
- `wikibooks_en_all_YYYY-MM.zim` - Free textbooks
- `wikivoyage_en_all_YYYY-MM.zim` - Travel guides
- `wikiquote_en_all_YYYY-MM.zim` - Quotes
- `stackoverflow_en_all_YYYY-MM.zim` - Stack Overflow Q&A
- `gutenberg_en_all_YYYY-MM.zim` - Project Gutenberg books
- `ted_ed_en_all_YYYY-MM.zim` - TED-Ed videos

## File Size Notes

- **Maxi** = Full content with images (largest)
- **Nopic** = Text-only, no images (smaller)
- **Top** = Curated top articles (smallest)

Choose based on your storage capacity and needs!

