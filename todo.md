# Sprint: Media Detail View

**Started:** 2026-06-19
**Status:** In Progress

## Goal
A Photos-style full-screen detail view, built as a dedicated `DetailViewController` with a custom transition. Full-screen media (pinch-zoom for images, AVPlayer for video), tool chrome (tap to toggle, all v1 tools stubbed), and an interactive pan-driven metadata panel. This finishes the *shell* the real processing tools hang off of — no core processing yet, but the job-system call sites get stubbed so the wiring is proven.

## Context
The detail view today is a placeholder overlay inside `GalleryViewController`: image animates in from the thumbnail, an empty blue metadata rectangle, tap to dismiss. No video, no tools, no gestures. This sprint promotes it to its own controller and builds the real foundation.

### Decided architecture (see docs/references/architecture.md)
- **Dedicated `DetailViewController`** presented from the gallery, with a `UIViewControllerTransitioningDelegate` for the thumbnail→fullscreen zoom + interactive swipe-to-dismiss.
- **Video playback = AVPlayer** (native, hardware decode — playback is presentation, so it lives in the UI). The Odin core player is the desktop path only.
- **Metadata panel resizes the media**: swipe up grows metadata + shrinks media; swipe down grows media to full-screen. Custom pan-driven layout, not a stock sheet. Read-only for now, structured to become editable.
- **Core owns logic, UI relays intent.** Tools are stubbed here; when wired, they call core's job API (`submit`/`poll`/`cancel`) and the UI polls per frame via `CADisplayLink`.
- **One-way calls**: UI polls, core never calls up. Poll fields live on the controller (no monitor class — flatten-ownership).

### v1 Roadmap (this sprint = the foundation for it)
- **Alpha** (shareable, gather feedback): gallery + detail view + **image compress + HEIC↔JPEG convert** + **video playback + compress + convert** (iOS = all platform APIs, no ffmpeg) + **save to library / share sheet**.
- **Beta** (feature-complete, competitive): trim (video) + crop/rotate (images) + metadata view + **strip location/EXIF** (privacy wedge). Stop line for editing: crop, rotate, trim — nothing else.
- **Release**: onboarding/permissions, edge cases (Live Photos, HDR), perf/battery, store assets.
- Bulk editing: out of v1, but the job system is built addressable so it's a fast follow.

---

## Phases

### Phase 1 — DetailViewController + Transition (the refactor)
- [ ] Create `DetailViewController` owning a media view
- [ ] Custom `UIViewControllerTransitioningDelegate`: thumbnail→fullscreen zoom animation
- [ ] Interactive swipe-down dismiss back to the source cell
- [ ] Move show/dismiss logic out of `GalleryViewController`; gallery just presents with the asset
- [ ] Pinch-to-zoom + pan for images via `UIScrollView`
- [ ] Load full-res image once presented (thumbnail → full-res swap)

### Phase 2 — Tool Chrome
- [ ] Top bar (close, share) + bottom tool bar
- [ ] Tap media to toggle chrome (auto-hide), fade animation, hidden during zoom
- [ ] Stub all v1 tool buttons: Edit Metadata, Edit (crop/rotate/trim), Compress, Convert
- [ ] Buttons present, no-op / "coming soon" affordance
- [ ] Respect safe areas

### Phase 3 — Metadata Panel
- [ ] Real content: file size, dimensions, duration (video), creation date, type
- [ ] Extend `PhotoLibrary` for any missing fields (EXIF/location later)
- [ ] Pan-driven panel: swipe up grows panel + shrinks media; swipe down → media full-screen
- [ ] Snap points (collapsed / partial / expanded) with rubber-banding
- [ ] Read-only, structured so fields can become editable later

### Phase 4 — Video Playback
- [ ] `AVPlayer` + `AVPlayerLayer` in the media view for video assets
- [ ] Transport controls in the chrome: play/pause, scrubber, elapsed/remaining
- [ ] Controls show/hide with chrome; pause on dismiss
- [ ] Audio session handling; decide loop vs stop-at-end

### Phase 5 — Job API Stub (prove the wiring, no real processing)
- [ ] Define the C ABI in core: `Job_Id` / `Job_State` / `Job_Status`, `squeeze_submit_*` / `squeeze_poll` / `squeeze_cancel`
- [ ] Core: addressable jobs + queue + one worker thread; a fake job that ramps progress 0→1 over a few seconds
- [ ] Add the job functions to the bridging header
- [ ] Wire a stubbed Compress button → submit fake job → poll per frame via `CADisplayLink` → progress UI → done
- [ ] Poll fields live on `DetailViewController` (no monitor class); invalidate link in `viewWillDisappear`
- [ ] Confirm desktop can call the same `poll()` from its frame loop

---

## Reference Snippets

### Core job API (bridging header)
```c
typedef uint64_t Job_Id;
typedef enum { JOB_QUEUED, JOB_RUNNING, JOB_DONE, JOB_FAILED, JOB_CANCELLED } Job_State;
typedef struct { Job_State state; float progress; int error_code; /* result */ } Job_Status;

Job_Id     squeeze_submit_convert(const char* src, int from_fmt, int to_fmt);
Job_Status squeeze_poll(Job_Id id);
void       squeeze_cancel(Job_Id id);
```

### Swift per-frame polling (grug — fields on the controller, no wrapper class)
```swift
final class DetailViewController: UIViewController {
	private var jobId: Job_Id = 0
	private var jobLink: CADisplayLink?

	private func startConvert(from: Int32, to: Int32) {
		self.jobId = squeeze_submit_convert(self.srcPath, from, to)
		let link = CADisplayLink(target: self, selector: #selector(pollJob))
		link.add(to: .main, forMode: .common)
		self.jobLink = link
	}

	@objc private func pollJob() {
		let status = squeeze_poll(self.jobId)
		self.progressBar.progress = status.progress
		switch status.state {
		case JOB_DONE:      self.stopPolling(); self.showResult(status)
		case JOB_FAILED:    self.stopPolling(); self.showError(status.error_code)
		case JOB_CANCELLED: self.stopPolling()
		default:            break
		}
	}

	private func stopPolling() {
		self.jobLink?.invalidate()
		self.jobLink = nil
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		self.stopPolling()
		// squeeze_cancel(self.jobId) — alpha: abort job on dismiss
	}
}
```

---

## Current Status

**Completed:**
- (starting)

**Up Next:**
- Phase 1 — promote to DetailViewController + custom transition

**Blocked:**
- (none)

---

## Learnings
- (captured as we go)

---

## Completion Checklist

Before archiving this sprint:
- [ ] All phases marked complete
- [ ] docs/references/ updated (detail view interaction, job system if it firms up)
- [ ] progress_tracker.md updated with summary + learnings
- [ ] Archive: `mv todo.md docs/sprints/completed/2026-06_media_detail_view.md`
