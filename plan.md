LEGO Missing Parts iOS App – Claude Plan
1. Refined UX flow (what happens in the app)
High‑level journey:

Enter LEGO set number.

See a vertical list of parts, each in a thick rounded card with image + part info.

Tap a card to increment “missing count” (1 tap = 1 missing, 2 taps = 2 missing, etc).

When finished with the set, submit:

Persist the missing pieces for that set.

Merge them into a global “all missing across all sets” pool.

From a global screen, export:

BrickLink XML wanted list.

Optional CSV/other formats for Rebrickable or spreadsheets.

1.1 Screen: “Enter set number”
Controls:

Text field: “Enter set number”.

Button: “Load set”.

Logic:

On tap, call Rebrickable /api/v3/lego/sets/{set_num}/ to validate and get metadata (name, year, image).

If valid, call /api/v3/lego/sets/{set_num}/parts/ to retrieve all inventory parts.

Persist a LegoSet + LegoParts locally.

UX detail:

Show loading state and simple error if set isn’t found or throttled.

1.2 Screen: “Parts list for set”
Layout:

Vertical ScrollView / List.

Each row is a thick rounded card:

Thumbnail image (from Rebrickable part image URL).

Part name.

Part number (design ID).

Color badge.

Required quantity for this set.

Missing count (integer) for this set.

Interaction model (tap = missing count):

Each card has missingCount starting at 0.

Single tap:

missingCount += 1.

Possibly long‑press or small “–” button to decrement.

Visual feedback:

Background color changes subtly once missingCount > 0.

Show “Missing: N” chip in the card.

Implementation sketch:

Keep the underlying stored values as haveQty; derive missing when exporting:

haveQty = requiredQty - missingCount.

Or store missingCount directly and derive haveQty when needed.

Extra touches:

Filter bar:

“All parts / Only missing / Only untouched”.

Quick actions:

“Mark all present” (sets all missing to 0).

1.3 Screen: “Submit missing pieces for this set”
When the user taps “Done with this set”:

For each part in the set, update persisted missingCount.

Recompute a global aggregated structure:

Key: (partNum, colorId).

Value: sum(missingCount for that key across all sets).

UX:

Show a confirmation: “Saved X missing items across Y unique parts for this set”.

Button: “Back to Sets” or “Go to Global Missing List”.

2. Data model specific to your flow
You can keep it lean and tailored to your tapping mechanic.

2.1 Local entities
LegoSet

id: UUID

setNum: String

name: String

imageUrl: URL?

totalParts: Int

LegoPartInstance (part as used in a specific set)

id: UUID

setId: UUID

partNum: String

colorId: Int

name: String?

imageUrl: URL?

requiredQty: Int

missingQty: Int (this is exactly what your tap increments)

Derived global aggregate (not stored, or stored in a table for speed):

GlobalMissingPart

partNum: String

colorId: Int

totalMissingQty: Int (sum over all LegoPartInstance.missingQty)

2.2 Rebrickable mapping & IDs
From /sets/{set_num}/parts/, you get everything needed to populate LegoPartInstance.

For future BrickLink XML export, you’ll eventually need BrickLink IDs:

Rebrickable exposes external IDs for each part via a part details endpoint, including BrickLink part numbers.

You can defer this to export time:

When exporting, for each unique (partNum, colorId) in the global list, call “get part” once to fetch external IDs and map to BrickLink.

3. Export / ordering design tied to this flow
Your tapping model feeds into a global missing list, which then feeds the exporter.

3.1 Global “Missing parts” screen
Shows all parts across all sets where totalMissingQty > 0.

Columns in each row:

Part image.

Name.

Color.

totalMissingQty.

Mini list of sets using it (optional, e.g. “Used in: 75192, 10214”).

Actions:

“Export as BrickLink XML”.

“Export as CSV”.

Optional: “Export per set”.

3.2 BrickLink XML export
Input: GlobalMissingPart[] from your aggregation.

For each item, you need:

BrickLink part ID.

BrickLink color ID.

Quantity = totalMissingQty.

XML shape (aligned with BrickLink Mass Upload):

xml
<INVENTORY>
  <ITEM>
    <ITEMTYPE>P</ITEMTYPE>
    <ITEMID>3001</ITEMID>
    <COLOR>5</COLOR>
    <MINQTY>3</MINQTY>
  </ITEM>
  <!-- Repeat for each unique part+color -->
</INVENTORY>
Implementation path:

Take GlobalMissingPart[].

Map to BrickLink IDs via Rebrickable “get part” (for part) and color mapping (color details / static lookup).

Build XML string.

Present:

Share sheet to save as .xml.

Button to “Copy XML”.

User then:

Goes to BrickLink → Wanted List → Upload → “BrickLink XML format” tab and paste the XML.

3.3 Future: direct BrickLink wanted list via API
“Order now” button in the app:

Implement OAuth to BrickLink.

Create a wanted list for “Missing pieces”.

Push each GlobalMissingPart item via the API.

Open BrickLink’s “Buy All” page for that list in Safari.

4. iOS implementation details mapped to your UX
4.1 UI mechanics for tap‑to‑increment
Example PartCard in SwiftUI:

swift
struct PartCard: View {
    @Binding var missingQty: Int
    let part: LegoPartInstance

    var body: some View {
        HStack {
            // Image + labels for part
            VStack(alignment: .leading) {
                Text(part.name ?? part.partNum)
                    .font(.headline)
                Text("Part: \(part.partNum) • Color: \(part.colorId)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Required: \(part.requiredQty)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Missing: \(missingQty)")
                .padding(8)
                .background(missingQty > 0 ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(missingQty > 0 ? Color.red.opacity(0.05) : Color(.systemBackground))
                .shadow(radius: 2)
        )
        .onTapGesture {
            missingQty += 1
        }
        .contextMenu {
            Button("Reset") { missingQty = 0 }
            Button("Decrement") {
                if missingQty > 0 { missingQty -= 1 }
            }
        }
    }
}
4.2 Keeping per‑set and global in sync
When user taps “Done” on the set:

Persist updated missingQty for all parts in that set.

Recompute global aggregate:

Use a SQL GROUP BY partNum, colorId to sum missingQty, or do a reduce in memory.

Global “Missing parts” reads only from the aggregate.

5. Implementation milestones
Wire up Rebrickable fetch for sets and set parts.

Build the “Enter set number” and “Parts list” screens with tap‑to‑increment.

Persist per‑set missingQty and implement the “Done with this set” flow.

Implement the global aggregate and global missing list screen.

Add CSV export, then BrickLink XML export, using part/color ID mapping.