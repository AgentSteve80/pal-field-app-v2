//
//  EditableBuilder.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import Foundation
import SwiftData

@Model
final class EditableBuilder {
    var id: UUID = UUID()
    var name: String = ""
    var highlight: String = ""
    var dmarkItems: [String] = []
    var wiringItems: [String] = []
    var enclosureItems: [String] = []
    var fppItems: [String] = []
    var modelItems: [String] = []
    var notesItems: [String] = []
    var sortOrder: Int = 0

    init(name: String, highlight: String, dmark: [String] = [], wiring: [String] = [], enclosure: [String] = [], fpp: [String] = [], model: [String] = [], notes: [String] = [], sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.highlight = highlight
        self.dmarkItems = dmark
        self.wiringItems = wiring
        self.enclosureItems = enclosure
        self.fppItems = fpp
        self.modelItems = model
        self.notesItems = notes
        self.sortOrder = sortOrder
    }
}

// MARK: - Default Builder Data

struct DefaultBuilderData {
    static func seedBuilders(context: ModelContext) {
        // Check if builders already exist
        let descriptor = FetchDescriptor<EditableBuilder>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else { return }

        let builders = [
            EditableBuilder(
                name: "MI Homes",
                highlight: "5 wires Minimum",
                dmark: [
                    "Flex tube and 1 coax",
                    "Single outlet jblock",
                    "Flash sides and top",
                    "Coil wires inside and blank plate"
                ],
                wiring: [
                    "Data Only",
                    "Dual ports located in family room and owners bedroom",
                    "1 WAP",
                    "1 hub keypad per print. If not marked 4 inches above garage entry light switch",
                    "All outlets on exterior walls must be in a blue box",
                    "9\" from corner or door frame"
                ],
                enclosure: [
                    "30 inch OnQ enclosure placed per print",
                    "Please contact super if have any questions on the location",
                    "Must add scabbed 2x4 horizontally to corners of enclosure if not attached to stud on both sides"
                ],
                fpp: [
                    "2 HDMI and pass through cat 6",
                    "OnQs that are in a closet at 56\" AFF from the top of the OnQ"
                ],
                model: ["Wires run to enclosure"],
                notes: [
                    "3 Story Townhomes:",
                    "Tube ran to the garage ceiling",
                    "1 coax and 1 data ran to the side of the unit"
                ],
                sortOrder: 0
            ),
            EditableBuilder(
                name: "Pulte Homes",
                highlight: "Flex tube only",
                dmark: [
                    "Flex tube only",
                    "Jblock and flash on sides and top",
                    "If brick exterior, install jblock 8 inches above the brick line or even with the bottom of the electric meter"
                ],
                wiring: ["Dual port in family room"],
                enclosure: [
                    "30 inch OnQ enclosure placed behind the laundry door, unless it has a basement",
                    "If it has a basement, enclosure must be located there",
                    "Must add scabbed 2x4 horizontally to corners of enclosure if not attached to stud on both sides",
                    "OnQs that are in a closet at 56\" AFF from the top of the OnQ"
                ],
                fpp: ["2 HDMI, pass through cat 6, Tube"],
                model: [
                    "Office data lines homerun to office kiosk",
                    "Kiosk will get its own dmark run, as well as 1 coax 1 data from kiosk to enclosure location",
                    "Home wires homerun to enclosure"
                ],
                notes: ["Stellar Floorplan can must be to 52 inches to bottom of enclosure"],
                sortOrder: 1
            ),
            EditableBuilder(
                name: "Beazer Homes",
                highlight: "Flex tape",
                dmark: [
                    "Flex tube and 1 coax",
                    "Flash card",
                    "Jblock",
                    "Flash tape on sides and top",
                    "Add bubble box at trim"
                ],
                wiring: [
                    "Dual ports located in the family room, owner's bedroom, loft",
                    "All wires in blue boxes only"
                ],
                enclosure: [
                    "30 inch OnQ enclosure marked on prints",
                    "Typically a laundry room or owner's bedroom closet",
                    "Must add scabbed 2x4 horizontally to corners of enclosure if not attached to stud on both sides",
                    "OnQs that are in a closet at 56\" AFF from the top of the OnQ"
                ],
                fpp: [
                    "Tube only",
                    "Use a special enclosed nail in conduit box"
                ],
                model: [
                    "Wires ran to enclosure",
                    "Office wires homerun in office to termination point",
                    "1 coax and 1 data ran to dmark and to enclosure from office homerun location"
                ],
                notes: [],
                sortOrder: 2
            ),
            EditableBuilder(
                name: "Drees Homes",
                highlight: "Flextape on jblock",
                dmark: [
                    "Flex tube and 1 coax",
                    "Flash card",
                    "Jblock and flash sides and top",
                    "If brick exterior, install jblock 8 inches above the brick line",
                    "Bubble box added at trim",
                    "FLEXTAPE on jblock"
                ],
                wiring: [
                    "4 wires any configuration",
                    "1 WAP"
                ],
                enclosure: [
                    "30 inch OnQ enclosure placed in the owner's bedroom closet, unless it has a basement",
                    "If has basement, enclosure to be placed under basement stairs",
                    "Must add scabbed 2x4 horizontally to corners of enclosure if not attached to stud on both sides",
                    "OnQs that are in a closet at 56\" AFF from the top of the OnQ"
                ],
                fpp: [
                    "2 HDMI and pass through cat 6",
                    "Or can be flex tube only, check contract"
                ],
                model: ["All wires ran to enclosure"],
                notes: [],
                sortOrder: 3
            ),
            EditableBuilder(
                name: "Epcon Homes",
                highlight: "Blue flash card",
                dmark: [
                    "Per contract - can be tube, wires, or both",
                    "Refer to contract for specifics",
                    "Blue flash card",
                    "Zip tape flashing on sides and top"
                ],
                wiring: [
                    "2 to 3 data marked on print",
                    "All wires must be in blue boxes with the exception of FPPs"
                ],
                enclosure: [
                    "30 inch OnQ enclosure",
                    "Marked in the closet",
                    "Centered in the rear of the closet no higher than 68 inches to the top",
                    "CAN NOT BE ON EXTERIOR WALL OR WALL SHARED WITH GARAGE",
                    "Must add scabbed 2x4 horizontally to corners of enclosure if not attached to stud on both sides",
                    "OnQs that are in a closet at 56\" AFF from the top of the OnQ"
                ],
                fpp: [
                    "2 HDMIs, pass through cat 6, tube",
                    "Can be tube only, check contract"
                ],
                model: ["All wires ran to enclosure"],
                notes: [
                    "Courtyards Westfield:",
                    "Dmark must be tube and 1 coax 1 data"
                ],
                sortOrder: 4
            )
        ]

        for builder in builders {
            context.insert(builder)
        }

        try? context.save()
    }
}
