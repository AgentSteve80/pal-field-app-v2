//
//  BuilderInfo.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import Foundation

// MARK: - Builder Standards

struct BuilderStandard: Identifiable {
    let id = UUID()
    let name: String
    let highlight: String  // Main thing to remember
    let dmark: [String]
    let wiring: [String]
    let enclosure: [String]
    let fpp: [String]
    let model: [String]
    let notes: [String]
}

struct BuilderData {
    static let builders: [BuilderStandard] = [
        BuilderStandard(
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
            model: [
                "Wires run to enclosure"
            ],
            notes: [
                "3 Story Townhomes:",
                "• Tube ran to the garage ceiling",
                "• 1 coax and 1 data ran to the side of the unit"
            ]
        ),
        BuilderStandard(
            name: "Pulte Homes",
            highlight: "Flex tube only",
            dmark: [
                "Flex tube only",
                "Jblock and flash on sides and top",
                "If brick exterior, install jblock 8 inches above the brick line or even with the bottom of the electric meter"
            ],
            wiring: [
                "Dual port in family room"
            ],
            enclosure: [
                "30 inch OnQ enclosure placed behind the laundry door, unless it has a basement",
                "If it has a basement, enclosure must be located there",
                "Must add scabbed 2x4 horizontally to corners of enclosure if not attached to stud on both sides",
                "OnQs that are in a closet at 56\" AFF from the top of the OnQ"
            ],
            fpp: [
                "2 HDMI, pass through cat 6, Tube"
            ],
            model: [
                "Office data lines homerun to office kiosk",
                "Kiosk will get its own dmark run, as well as 1 coax 1 data from kiosk to enclosure location",
                "Home wires homerun to enclosure"
            ],
            notes: [
                "**Stellar Floorplan** can must be to 52 inches to bottom of enclosure"
            ]
        ),
        BuilderStandard(
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
            notes: []
        ),
        BuilderStandard(
            name: "Drees Homes",
            highlight: "Flextape on jblock",
            dmark: [
                "Flex tube and 1 coax",
                "Flash card",
                "Jblock and flash sides and top",
                "If brick exterior, install jblock 8 inches above the brick line or even with the bottom of the electric meter",
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
            model: [
                "All wires ran to enclosure"
            ],
            notes: []
        ),
        BuilderStandard(
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
            model: [
                "All wires ran to enclosure"
            ],
            notes: [
                "Courtyards Westfield:",
                "• Dmark must be tube and 1 coax 1 data"
            ]
        )
    ]
}

// MARK: - Pulte Construction Contacts

struct PulteContact: Identifiable {
    let id = UUID()
    let community: String
    let city: String
    let officeLocation: String
    let managers: [(name: String, phone: String, email: String)]
}

struct PulteContactData {
    static let eastSide: [PulteContact] = [
        PulteContact(
            community: "Magnolia",
            city: "",
            officeLocation: "Magnolia",
            managers: [("Justin Maxson", "317-650-3791", "justin.maxson@pulte.com")]
        ),
        PulteContact(
            community: "Towns @ RiverWest",
            city: "Noblesville",
            officeLocation: "Riverwest",
            managers: [("Caden Bauer", "317-447-2885", "jason.bauer@pulte.com")]
        ),
        PulteContact(
            community: "Towns @ RiverPlace",
            city: "Fishers",
            officeLocation: "Riverplace",
            managers: [("Jason Bauer", "317-447-2885", "jason.bauer@pulte.com")]
        ),
        PulteContact(
            community: "Magnolia Ridge",
            city: "Noblesville",
            officeLocation: "Magnolia",
            managers: [
                ("Nick Durr", "317-766-0431", "nicklaus.durr@pulte.com"),
                ("Charles Millard", "317-677-2313", "charles.millard@pulte.com")
            ]
        ),
        PulteContact(
            community: "Ambleside Townhomes",
            city: "Carmel",
            officeLocation: "Ambleside",
            managers: [("Scott Baker", "317-900-9977", "scott.barker@pulte.com")]
        ),
        PulteContact(
            community: "Meadowstone",
            city: "Carmel",
            officeLocation: "Meadowstone",
            managers: [("Jack Sweigart", "317-376-2961", "jack.sweigart@pulte.com")]
        ),
        PulteContact(
            community: "Finch Creek Del Webb",
            city: "Noblesville",
            officeLocation: "Finch Creek",
            managers: [
                ("Mitchell Graff", "317-371-3421", "mitchell.graff@pulte.com"),
                ("Kyle Koehne", "317-697-8520", "kyle.koehne@pulte.com"),
                ("Dayton Thurman", "618-554-3381", "dayton.thurman@pulte.com"),
                ("Connor Hammerle", "317-677-5135", "connor.hammerle@pulte.com")
            ]
        ),
        PulteContact(
            community: "Finch Creek Parkside",
            city: "Noblesville",
            officeLocation: "Finch Creek",
            managers: [
                ("Austin Williams", "317-345-6788", "austin.williams@pulte.com"),
                ("Cade Brouyette", "574-551-4252", "cade.brouyette@pulte.com")
            ]
        ),
        PulteContact(
            community: "Lancaster",
            city: "Westfield",
            officeLocation: "Lancaster",
            managers: [
                ("Michael Kaim", "317-431-0694", "michael.kaim@pulte.com"),
                ("Scott Barker", "317-900-9977", "scott.barker@pulte.com"),
                ("Max Dragonette", "317-289-6004", "max.dragonette@pulte.com")
            ]
        )
    ]

    static let central: [PulteContact] = [
        PulteContact(
            community: "Kimblewick",
            city: "Westfield",
            officeLocation: "Kimblewick",
            managers: [
                ("Ethan Rollins", "317-400-1244", "ethan.rollins@pulte.com"),
                ("Jake Hendricks", "765-894-5062", "jacob.hendricks@pulte.com"),
                ("Cameron Luczka", "937-776-4360", "cameron.luczka@pulte.com")
            ]
        ),
        PulteContact(
            community: "Appaloosa",
            city: "Zionsville",
            officeLocation: "Appaloosa",
            managers: [("Scott Barker", "317-900-9977", "scott.barker@pulte.com")]
        ),
        PulteContact(
            community: "Devonshire",
            city: "Zionsville",
            officeLocation: "Devonshire",
            managers: [
                ("Jake Hendricks", "765-894-5062", "jacob.hendricks@pulte.com"),
                ("Cameron Luczka", "937-776-4360", "cameron.luczka@pulte.com"),
                ("Scott Barker", "317-900-9977", "scott.barker@pulte.com")
            ]
        ),
        PulteContact(
            community: "Cardinal Pointe",
            city: "Whitestown",
            officeLocation: "Cardinal Pointe",
            managers: [("Nick Hamman", "317-340-9909", "nick.hamman@pulte.com")]
        ),
        PulteContact(
            community: "Bridle Oaks",
            city: "Whitestown",
            officeLocation: "Bridle Oaks",
            managers: [("Christian Balint", "817-874-3135", "christian.balint@pulte.com")]
        ),
        PulteContact(
            community: "Highlands",
            city: "Whitestown",
            officeLocation: "Highlands",
            managers: [("Sarah Mitchell", "317-372-9017", "sarah.mitchell@pulte.com")]
        ),
        PulteContact(
            community: "Towns @ Union",
            city: "Westfield",
            officeLocation: "Towns @ Union",
            managers: [
                ("Ethan Rollins", "317-400-1244", "ethan.rollins@pulte.com"),
                ("Joel Edwards", "317-719-6238", "joel.edwards@pultegroup.com")
            ]
        )
    ]

    static let westSide: [PulteContact] = [
        PulteContact(
            community: "Greystone",
            city: "Brownsburg",
            officeLocation: "Oakdale",
            managers: [("Anthony Martin", "260-445-2496", "anthony.martin@pulte.com")]
        ),
        PulteContact(
            community: "Promenade",
            city: "Brownsburg",
            officeLocation: "Promenade",
            managers: [("Anthony Martin", "260-445-2496", "anthony.martin@pulte.com")]
        ),
        PulteContact(
            community: "Rivendell",
            city: "Avon",
            officeLocation: "Rivendell",
            managers: [("Scott Sinclair", "317-363-8441", "scott.sinclair@pulte.com")]
        ),
        PulteContact(
            community: "Oakdale",
            city: "Brownsburg",
            officeLocation: "Oakdale",
            managers: [("Anthony Martin", "260-445-2496", "anthony.martin@pulte.com")]
        ),
        PulteContact(
            community: "Brookstone",
            city: "Avon",
            officeLocation: "Brookstone",
            managers: [("Warren Gamblin", "317-224-5361", "warren.gamblin@pulte.com")]
        ),
        PulteContact(
            community: "Trescott",
            city: "Plainfield",
            officeLocation: "Trescott",
            managers: [("Caleb Ard", "217-273-1536", "caleb.ard@pulte.com")]
        ),
        PulteContact(
            community: "Hobbs Station",
            city: "Plainfield",
            officeLocation: "Hobbs Station",
            managers: [
                ("Caleb Ard", "217-273-1536", "caleb.ard@pulte.com"),
                ("Warren Gamblin", "317-224-5361", "warren.gamblin@pulte.com")
            ]
        ),
        PulteContact(
            community: "Sagebriar",
            city: "Greenwood",
            officeLocation: "Sagebriar",
            managers: [
                ("Tony Magnabosco", "317-402-8082", "tony.magnabosco@pulte.com"),
                ("Sydney Balint", "682-283-1445", "sydney.balint@pulte.com"),
                ("Tanner Hubbard", "317-201-4631", "tanner.hubbard@pulte.com"),
                ("Brian Wilson", "317-213-9088", "brian.wilson@pulte.com")
            ]
        )
    ]

    static let areaManagers: [(area: String, name: String, phone: String, email: String)] = [
        ("East Side", "Jack Sweigart (Sr. Field Manager)", "317-376-2961", "jack.sweigart@pulte.com"),
        ("East Side", "Michael Kaim (Sr. Field Manager)", "317-431-0694", "michael.kaim@pulte.com"),
        ("Central", "Braxton Graff (Sr. Field Manager)", "317-435-9906", "braxton.graff@pulte.com"),
        ("West Side", "Scott Sinclair (Sr. Construction Manager)", "317-363-8441", "scott.sinclair@pulte.com"),
        ("West Side", "Sean Lindhout (Sr. Construction Manager)", "317-995-7390", "sean.lindhout@pulte.com")
    ]

    static var allContacts: [PulteContact] {
        eastSide + central + westSide
    }
}
