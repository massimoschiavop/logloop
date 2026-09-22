import SwiftData
import SwiftUI

/// Righe di esercizi (con eventuali categorie) per un livello foglia della gerarchia scheda/
/// gruppo/sottogruppo, pensate per confluire nell'unica card della scheda. Ogni riga ha
/// altezza fissa e un separatore disegnato a mano a piena larghezza (vedi `.rowStyle()`),
/// così tutte le righe della card — a qualunque livello — risultano identiche.
struct ExerciseListContent: View {
    let exercises: [Exercise]
    let template: Template?
    /// Crea un nuovo esercizio (nella categoria indicata) e lo restituisce, per poterlo
    /// mostrare subito in modifica inline con il focus sul titolo.
    let onAdd: (TemplateCategory?) -> Exercise
    let onEdit: (Exercise) -> Void
    let onDelete: (_ list: [Exercise], _ offsets: IndexSet) -> Void
    let onMove: (_ list: [Exercise], _ source: IndexSet, _ destination: Int) -> Void
    /// Mostra una riga con la durata totale in fondo: solo per l'uso a livello di scheda
    /// piatta, dove non c'è già un header di gruppo/sottogruppo che la riporta.
    var showsTotal: Bool = false

    @Environment(\.modelContext) private var context
    /// L'esercizio appena creato, ancora in modifica inline del titolo (finché non perde
    /// il focus). Al massimo uno per volta.
    @State private var inlineExercise: Exercise?
    @FocusState private var isInlineFieldFocused: Bool

    var body: some View {
        Group {
            rows

            if showsTotal, totalDurationSeconds > 0 {
                LabeledContent("Durata totale", value: Formatters.compact(totalDurationSeconds))
                    .rowStyle()
            }
        }
        .onChange(of: isInlineFieldFocused) { _, focused in
            if !focused, inlineExercise != nil {
                finishInlineEditing()
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        if groups.isEmpty {
            Text("Nessun esercizio.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .rowStyle()
        } else {
            ForEach(groups, id: \.title) { group in
                CategorySection(
                    group: group,
                    inlineExerciseID: inlineExercise?.id,
                    isInlineFieldFocused: $isInlineFieldFocused,
                    onAddExercise: { addExercise(category: group.category) },
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onMove: onMove
                )
            }
        }
    }

    private func addExercise(category: TemplateCategory?) {
        let exercise = onAdd(category)
        inlineExercise = exercise
        isInlineFieldFocused = true
    }

    private func finishInlineEditing() {
        if let exercise = inlineExercise, exercise.name.trimmed.isEmpty {
            context.delete(exercise)
        }
        inlineExercise = nil
    }

    private var totalDurationSeconds: Int {
        exercises.reduce(0) { $0 + $1.durationSeconds }
    }

    /// Una sezione per ogni categoria del template — anche senza esercizi, per avere sempre
    /// un posto dove premere "+" — più una per gli esercizi senza categoria, se ce ne sono
    /// (o se il template non ne definisce nessuna, come unico punto di aggiunta).
    private var groups: [CategoryGroup] {
        guard let template else { return [] }
        let categories = template.categories

        var result: [CategoryGroup] = categories.map { category in
            CategoryGroup(
                title: category.name,
                colorHex: category.colorHex,
                category: category,
                exercises: exercises.filter { $0.category?.identifier == category.identifier }
            )
        }
        let uncategorized = exercises.filter { $0.category == nil }
        if !uncategorized.isEmpty || categories.isEmpty {
            result.append(CategoryGroup(
                title: "Senza categoria",
                colorHex: "#8E8E93",
                category: nil,
                exercises: uncategorized
            ))
        }
        return result
    }
}

private struct CategoryGroup {
    let title: String
    let colorHex: String
    let category: TemplateCategory?
    let exercises: [Exercise]
}

private struct CategorySection: View {
    let group: CategoryGroup
    let inlineExerciseID: PersistentIdentifier?
    var isInlineFieldFocused: FocusState<Bool>.Binding
    let onAddExercise: () -> Void
    let onEdit: (Exercise) -> Void
    let onDelete: (_ list: [Exercise], _ offsets: IndexSet) -> Void
    let onMove: (_ list: [Exercise], _ source: IndexSet, _ destination: Int) -> Void

    @State private var isExpanded = true

    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HierarchyHeader(
                    title: group.title,
                    titleColor: Color(hex: group.colorHex),
                    durationSeconds: totalDurationSeconds,
                    isExpanded: isExpanded,
                    level: .category
                )
            }
            .buttonStyle(.plain)

            Button(action: onAddExercise) {
                Image(systemName: "plus.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
            .buttonStyle(.plain)
        }
        .rowStyle(background: HierarchyLevel.category.background)

        if isExpanded {
            ForEach(group.exercises) { exercise in
                if exercise.id == inlineExerciseID {
                    InlineExerciseField(exercise: exercise, isFocused: isInlineFieldFocused)
                } else {
                    Button { onEdit(exercise) } label: {
                        ExerciseRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                    .rowStyle()
                }
            }
            .onDelete { onDelete(group.exercises, $0) }
            .onMove { onMove(group.exercises, $0, $1) }
        }
    }

    private var totalDurationSeconds: Int {
        group.exercises.reduce(0) { $0 + $1.durationSeconds }
    }
}

/// Campo di testo mostrato al posto della riga per un esercizio appena creato con il "+" di
/// categoria: permette di scrivere subito il titolo, con il focus già posizionato.
private struct InlineExerciseField: View {
    @Bindable var exercise: Exercise
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        TextField("Nome esercizio", text: $exercise.name)
            .font(.subheadline.weight(.medium))
            .focused(isFocused)
            .submitLabel(.done)
            .onSubmit { isFocused.wrappedValue = false }
            .rowStyle()
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(exercise.name.isEmpty ? "Senza nome" : exercise.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                if !details.isEmpty {
                    Text(details)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(Formatters.clock(exercise.durationSeconds))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var details: String {
        exercise.fieldValues
            .filter { !$0.isEmpty }
            .sorted { ($0.definition?.sortIndex ?? 0) < ($1.definition?.sortIndex ?? 0) }
            .map { "\($0.definition?.name ?? ""): \($0.displayValue)" }
            .joined(separator: " · ")
    }
}

/// I tre livelli di intestazione della gerarchia (gruppo, sottogruppo, categoria), distinti
/// solo da una scala di grigi crescente e dal peso del testo — nessun colore.
enum HierarchyLevel {
    case group
    case subgroup
    case category

    var background: Color {
        switch self {
        case .group: return Color.primary.opacity(0.16)
        case .subgroup: return Color.primary.opacity(0.08)
        case .category: return Color.primary.opacity(0.035)
        }
    }

    /// Stesso font per tutti i livelli: quello finora usato per le categorie.
    var font: Font {
        .footnote.weight(.semibold)
    }
}

/// Riga di intestazione condivisa da gruppo, sottogruppo e categoria: titolo (sempre in
/// maiuscolo, stesso font per tutti i livelli), durata e freccia di espansione.
struct HierarchyHeader: View {
    let title: String
    var titleColor: Color? = nil
    let durationSeconds: Int
    let isExpanded: Bool
    let level: HierarchyLevel

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(level.font)
                .foregroundStyle(titleColor ?? .primary)
            Spacer()
            if durationSeconds > 0 {
                Text(Formatters.compact(durationSeconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .contentShape(Rectangle())
    }
}

/// Stile comune a ogni riga della card: altezza fissa (uguale per tutte, a prescindere dal
/// contenuto) e margine laterale nel contenuto. Sfondo e separatore vivono entrambi dentro
/// `.listRowBackground(_:)`, l'unico hook che SwiftUI garantisce disteso su tutta la riga in
/// una List — un semplice `.background()`/`.overlay()` sul contenuto segue invece le
/// dimensioni del contenuto stesso e produce riempimenti/separatori incoerenti da riga a
/// riga. Il separatore di sistema non è utilizzabile perché lo stile "insetGrouped" gli
/// impone un margine fisso legato al bordo della card, che non possiamo controllare.
extension View {
    func rowStyle(background: Color = .clear) -> some View {
        padding(.horizontal, 16)
            .frame(height: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(
                ZStack(alignment: .bottom) {
                    background
                    Rectangle()
                        .fill(Color.primary.opacity(0.15))
                        .frame(height: 0.5)
                }
            )
    }
}
