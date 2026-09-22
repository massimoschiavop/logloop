import SwiftData
import SwiftUI

/// Vista di popolamento di una scheda già creata: mostra l'intera struttura (scheda,
/// eventuali gruppi e sottogruppi) come un'unica card continua in stile "insetGrouped"
/// (arrotondata solo in cima e in fondo), con righe tutte della stessa altezza, separatori
/// disegnati a mano a piena larghezza e livelli distinti solo da una scala di grigi (nessun
/// colore). La struttura si definisce alla creazione della scheda
/// (SheetDetailView/GroupDetailView/SubgroupDetailView) e qui non è più modificabile.
struct SheetOutlineView: View {
    @Bindable var sheet: ExerciseSheet

    @Environment(\.modelContext) private var context
    /// Lo sheet di modifica esercizio è presentato da questa view radice (non da una riga
    /// dentro un ForEach): agganciarlo a una riga generata dinamicamente farebbe ricomporre
    /// il presentatore mentre l'utente modifica l'esercizio, causando lo sheet a
    /// sparire/riapparire.
    @State private var editingExercise: Exercise?
    @State private var editingTemplate: Template?
    @State private var editingIsNew = false

    var body: some View {
        List {
            Section {
                if sheet.isGrouped {
                    ForEach(sheet.groups) { group in
                        GroupOutlineRows(group: group, onEdit: edit)
                    }
                } else {
                    ExerciseListContent(
                        exercises: sheet.exercises,
                        template: sheet.template,
                        onAdd: addExercise,
                        onEdit: { edit($0, template: sheet.template) },
                        onDelete: deleteExercises,
                        onMove: moveExercises,
                        showsTotal: true
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(sheet.name.isEmpty ? "Scheda" : sheet.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingExercise) { exercise in
            ExerciseEditorView(
                exercise: exercise,
                template: editingTemplate,
                isNew: editingIsNew
            )
        }
    }

    private func addExercise(category: TemplateCategory?) -> Exercise {
        let template = sheet.template
        let exercise = Exercise(
            name: "",
            durationSeconds: template?.defaultDurationSeconds ?? 300,
            category: category,
            sortIndex: sheet.exercisesStorage.count
        )
        exercise.sheet = sheet
        context.insert(exercise)
        return exercise
    }

    private func edit(_ exercise: Exercise, template: Template?) {
        editingIsNew = false
        editingTemplate = template
        editingExercise = exercise
    }

    private func deleteExercises(_ list: [Exercise], at offsets: IndexSet) {
        for index in offsets { context.delete(list[index]) }
        sheet.exercises.renumber()
    }

    private func moveExercises(_ list: [Exercise], from source: IndexSet, to destination: Int) {
        var reordered = list
        reordered.move(fromOffsets: source, toOffset: destination)
        let slots = list.map(\.sortIndex).sorted()
        for (element, slot) in zip(reordered, slots) {
            element.sortIndex = slot
        }
    }
}

/// Righe di un gruppo (header + contenuto), pensate per confluire nell'unica card della
/// scheda: nessun `Section` proprio, altrimenti spezzerebbe la card in più pezzi.
private struct GroupOutlineRows: View {
    @Bindable var group: SheetGroup
    let onEdit: (Exercise, Template?) -> Void

    @Environment(\.modelContext) private var context
    @State private var isExpanded = true

    var body: some View {
        Group {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HierarchyHeader(
                    title: group.name.isEmpty ? "Senza nome" : group.name,
                    durationSeconds: group.totalDurationSeconds,
                    isExpanded: isExpanded,
                    level: .group
                )
            }
            .buttonStyle(.plain)
            .rowStyle(background: HierarchyLevel.group.background)

            if isExpanded {
                if group.isGrouped {
                    ForEach(group.subgroups) { subgroup in
                        SubgroupOutlineRows(subgroup: subgroup, onEdit: onEdit)
                    }
                } else {
                    ExerciseListContent(
                        exercises: group.exercises,
                        template: group.template,
                        onAdd: addExercise,
                        onEdit: { onEdit($0, group.template) },
                        onDelete: deleteExercises,
                        onMove: moveExercises
                    )
                }
            }
        }
    }

    private func addExercise(category: TemplateCategory?) -> Exercise {
        let template = group.template
        let exercise = Exercise(
            name: "",
            durationSeconds: template?.defaultDurationSeconds ?? 300,
            category: category,
            sortIndex: group.exercisesStorage.count
        )
        exercise.group = group
        context.insert(exercise)
        return exercise
    }

    private func deleteExercises(_ list: [Exercise], at offsets: IndexSet) {
        for index in offsets { context.delete(list[index]) }
        group.exercises.renumber()
    }

    private func moveExercises(_ list: [Exercise], from source: IndexSet, to destination: Int) {
        var reordered = list
        reordered.move(fromOffsets: source, toOffset: destination)
        let slots = list.map(\.sortIndex).sorted()
        for (element, slot) in zip(reordered, slots) {
            element.sortIndex = slot
        }
    }
}

/// Righe di un sottogruppo, con la stessa logica di GroupOutlineRows: nessun `Section`
/// proprio, per restare nella card unica della scheda.
private struct SubgroupOutlineRows: View {
    @Bindable var subgroup: SheetSubgroup
    let onEdit: (Exercise, Template?) -> Void

    @Environment(\.modelContext) private var context
    @State private var isExpanded = true

    var body: some View {
        Group {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HierarchyHeader(
                    title: subgroup.name.isEmpty ? "Senza nome" : subgroup.name,
                    durationSeconds: subgroup.totalDurationSeconds,
                    isExpanded: isExpanded,
                    level: .subgroup
                )
            }
            .buttonStyle(.plain)
            .rowStyle(background: HierarchyLevel.subgroup.background)

            if isExpanded {
                ExerciseListContent(
                    exercises: subgroup.exercises,
                    template: subgroup.template,
                    onAdd: addExercise,
                    onEdit: { onEdit($0, subgroup.template) },
                    onDelete: deleteExercises,
                    onMove: moveExercises
                )
            }
        }
    }

    private func addExercise(category: TemplateCategory?) -> Exercise {
        let template = subgroup.template
        let exercise = Exercise(
            name: "",
            durationSeconds: template?.defaultDurationSeconds ?? 300,
            category: category,
            sortIndex: subgroup.exercisesStorage.count
        )
        exercise.subgroup = subgroup
        context.insert(exercise)
        return exercise
    }

    private func deleteExercises(_ list: [Exercise], at offsets: IndexSet) {
        for index in offsets { context.delete(list[index]) }
        subgroup.exercises.renumber()
    }

    private func moveExercises(_ list: [Exercise], from source: IndexSet, to destination: Int) {
        var reordered = list
        reordered.move(fromOffsets: source, toOffset: destination)
        let slots = list.map(\.sortIndex).sorted()
        for (element, slot) in zip(reordered, slots) {
            element.sortIndex = slot
        }
    }
}
