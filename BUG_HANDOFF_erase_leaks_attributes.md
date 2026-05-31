# Bug Handoff: ANSI Erase-Operationen leaken Zell-Attribute

**Projekt:** [tui-td](https://github.com/vurte/tui-td) (git@github.com:vurte/tui-td.git)
**Betrifft:** `lib/tui_td/ansi_parser.rb`
**Schweregrad:** Mittel — visuelle Artefakte in HTML/PNG-Screenshots, kein Fehler im echten Terminal

---

## Problem

Die Erase-Methoden setzen nur `cell[:char] = " "`, aber nicht `fg`, `bg`, `bold`, `italic`, `underline`, `blink` zurück. Wenn eine Zeile per `\e[K` (Erase Line) gelöscht und dann mit kürzerem Inhalt überschrieben wird, behalten die nicht-überschriebenen Zellen ihre alten Attribute.

**Betroffene Methoden (6 Stück):**
- `_erase_line_right` (Zeile ~658)
- `_erase_line_left` (Zeile ~664)
- `_erase_line` (Zeile ~670)
- `_erase_down` (Zeile ~623)
- `_erase_up` (Zeile ~636)
- `_erase_all` (Zeile ~649)

Alle machen Varianten von:
```ruby
grid[r][ci][:char] = " "   # ❌ nur char, Attribute bleiben
```

## Konkretes Beispiel (aus Karat TUI)

1. Echo-Zeile wird geschrieben: `\n\e[48;5;236m...(volle Terminalbreite)...\e[0m`
   → Alle 100 Zellen der Zeile haben `bg: "color236"` (#303030, dunkelgrau)
2. Später wird diese Zeile mit `\e[K` gelöscht
   → Zellen haben `char: " "`, aber `bg` ist immer noch `"color236"`
3. Eine neue, kürzere Zeile (z.B. `? for shortcuts`) wird geschrieben
   → Nur ~20 Zellen werden überschrieben, die restlichen 80 zeigen den alten BG_DIM-Hintergrund

**Symptom im Screenshot:** Dunkelgraue Balken erscheinen im Banner, zwischen Responses und an anderen Stellen, wo sie nicht hingehören.

## Fix

```ruby
# Neue Hilfsmethode
def self._erase_cell(cell)
  cell.merge!(default_cell)
end

# default_cell ist bereits definiert:
# { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false, blink: false }
```

Alle 6 Erase-Methoden von `grid[r][ci][:char] = " "` auf `_erase_cell(grid[r][ci])` umstellen.

### Konkretes Diff

```diff
+    def self._erase_cell(cell)
+      cell.merge!(default_cell)
+    end

     def self._erase_down(cursor, grid, rows, cols)
       r = cursor[:row]
       c = cursor[:col]
-      (c...cols).each { |ci| grid[r][ci][:char] = " " if r < rows }
+      (c...cols).each { |ci| _erase_cell(grid[r][ci]) if r < rows }
       ((r + 1)...rows).each do |ri|
-        cols.times { |ci| grid[ri][ci][:char] = " " }
+        cols.times { |ci| _erase_cell(grid[ri][ci]) }
       end
     end

     def self._erase_up(cursor, grid, cols)
       r = cursor[:row]
       c = cursor[:col]
       (0...r).each do |ri|
-        cols.times { |ci| grid[ri][ci][:char] = " " }
+        cols.times { |ci| _erase_cell(grid[ri][ci]) }
       end
-      (0..c).each { |ci| grid[r][ci][:char] = " " }
+      (0..c).each { |ci| _erase_cell(grid[r][ci]) }
     end

     def self._erase_all(grid, rows, cols)
       rows.times do |ri|
-        cols.times { |ci| grid[ri][ci][:char] = " " }
+        cols.times { |ci| _erase_cell(grid[ri][ci]) }
       end
     end

     def self._erase_line_right(cursor, grid, cols)
       r = cursor[:row]
       c = cursor[:col]
-      (c...cols).each { |ci| grid[r][ci][:char] = " " if r < grid.length }
+      (c...cols).each { |ci| _erase_cell(grid[r][ci]) if r < grid.length }
     end

     def self._erase_line_left(cursor, grid, _cols)
       r = cursor[:row]
       c = cursor[:col]
-      (0..c).each { |ci| grid[r][ci][:char] = " " if r < grid.length }
+      (0..c).each { |ci| _erase_cell(grid[r][ci]) if r < grid.length }
     end

     def self._erase_line(cursor, grid, cols)
       r = cursor[:row]
-      cols.times { |ci| grid[r][ci][:char] = " " if r < grid.length }
+      cols.times { |ci| _erase_cell(grid[r][ci]) if r < grid.length }
     end
```

## Wie testen

### Unit-Test (in `spec/ansi_parser_spec.rb`)

Bestehende Tests prüfen nur `:char`, nicht `:bg`. Ergänzender Test:

```ruby
it "erase operations reset all cell attributes, not just char" do
  # 1. Schreibe Text mit BG_DIM-Hintergrund (color236)
  # 2. Lösche die Zeile mit EL erase-line (\e[2K)
  # 3. Prüfe dass ALLE Attribute auf default zurückgesetzt sind
  raw = "\e[48;5;236mHello\e[0m\e[2K"
  state = described_class.parse(raw, 10, 40)

  cell = state[:rows][0][0]
  expect(cell[:char]).to eq(" ")
  expect(cell[:bg]).to eq("default")
  expect(cell[:fg]).to eq("default")
  expect(cell[:bold]).to be false
  expect(cell[:italic]).to be false
  expect(cell[:underline]).to be false
  expect(cell[:blink]).to be false
end

it "erase-right after colored text resets background" do
  # BG_DIM auf ganzer Zeile, dann \e[0K ab Spalte 10
  raw = "\e[48;5;236m" + ("X" * 20) + "\e[0m\e[11G\e[0K"
  state = described_class.parse(raw, 10, 40)

  # Zellen vor Spalte 10: X mit bg=color236
  expect(state[:rows][0][0][:char]).to eq("X")
  expect(state[:rows][0][0][:bg]).to eq("color236")

  # Zellen ab Spalte 10: gelöscht, alle Attribute default
  expect(state[:rows][0][10][:char]).to eq(" ")
  expect(state[:rows][0][10][:bg]).to eq("default")
  expect(state[:rows][0][10][:fg]).to eq("default")
end
```

### Integrationstest (mit Karat als Consumer)

```bash
cd karat
bundle exec rspec spec/smoke/smoke_spec.rb --format documentation
# Danach:
grep -c 'background-color:#303030' tmp/smoke_screenshots/4.1*.html
# Erwartet: 4 (nur Echo-Zeilen mit ❯)
# Vor dem Fix: 4 mit char=space + bg=color236 Leaks → sichtbar als graue Balken
```

## Referenz

- ANSI `\e[K` (EL): https://en.wikipedia.org/wiki/ANSI_escape_code#CSI_(Control_Sequence_Introducer)_sequences
- ANSI `\e[J` (ED): gleiche Semantik, gleicher Fix nötig
- `default_cell` ist in `ansi_parser.rb` Zeile ~690 bereits definiert
