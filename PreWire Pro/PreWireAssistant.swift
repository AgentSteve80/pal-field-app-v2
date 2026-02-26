//
//  PreWireAssistant.swift
//  PreWire Pro
//
//  Created by Claude on 2/4/26.
//

import Foundation

struct AssistantResponse {
    let text: String
    let relatedTopics: [String]
    var emailResults: [SearchResult]
    var blueprintResults: [SearchResult]

    init(text: String, relatedTopics: [String], emailResults: [SearchResult] = [], blueprintResults: [SearchResult] = []) {
        self.text = text
        self.relatedTopics = relatedTopics
        self.emailResults = emailResults
        self.blueprintResults = blueprintResults
    }
}

class PreWireAssistant {
    static let shared = PreWireAssistant()
    private let searchService = LocalSearchService.shared

    private init() {}

    func answer(question: String, emails: [CachedEmail] = []) -> AssistantResponse {
        let q = question.lowercased()

        // Search emails and blueprints for context
        let emailResults = searchService.searchEmails(query: question, in: emails, limit: 3)
        let blueprintResults = searchService.searchBlueprints(query: question, limit: 2)

        // Helper to add search results to response
        func withSearchResults(_ response: AssistantResponse) -> AssistantResponse {
            var r = response
            r.emailResults = emailResults
            r.blueprintResults = blueprintResults
            return r
        }

        // Builder-specific questions
        if q.contains("mi home") || q.contains("mi ") && q.contains("home") {
            return withSearchResults(miHomesResponse(q))
        }
        if q.contains("pulte") {
            return withSearchResults(pulteResponse(q))
        }
        if q.contains("beazer") {
            return withSearchResults(beazerResponse(q))
        }
        if q.contains("drees") {
            return withSearchResults(dreesResponse(q))
        }
        if q.contains("epcon") {
            return withSearchResults(epconResponse(q))
        }

        // Topic-specific questions
        if q.contains("dmark") || q.contains("d-mark") || q.contains("d mark") {
            return withSearchResults(dmarkResponse(q))
        }
        if q.contains("enclosure") || q.contains("onq") || q.contains("on q") || q.contains("panel") {
            return withSearchResults(enclosureResponse(q))
        }
        if q.contains("fpp") || q.contains("flat panel") || q.contains("tv") || q.contains("mount") {
            return withSearchResults(fppResponse(q))
        }
        if q.contains("wire") || q.contains("wiring") || q.contains("cat") || q.contains("coax") {
            return withSearchResults(wiringResponse(q))
        }
        if q.contains("wap") || q.contains("wireless") || q.contains("access point") {
            return withSearchResults(wapResponse(q))
        }
        if q.contains("blue box") || q.contains("exterior") {
            return withSearchResults(blueBoxResponse(q))
        }
        if q.contains("flex") || q.contains("tube") {
            return withSearchResults(flextubeResponse(q))
        }
        if q.contains("jblock") || q.contains("j-block") || q.contains("j block") {
            return withSearchResults(jblockResponse(q))
        }

        // App feature questions
        if q.contains("invoice") {
            return withSearchResults(appResponse("Invoices", "Tap the document icon in the top right to generate a weekly invoice. You can also view past invoices in the Invoices section. Invoices include all jobs from the current week with itemized pricing."))
        }
        if q.contains("mileage") || q.contains("trip") || q.contains("track") {
            return withSearchResults(appResponse("Mileage Tracking", "Tap 'Track Mileage' on the dashboard to start GPS tracking. The app records your route in the background. Stop the trip when you arrive. Mileage is automatically calculated for tax deductions at $0.67/mile."))
        }
        if q.contains("expense") || q.contains("receipt") {
            return withSearchResults(appResponse("Expenses", "Go to Expenses to log business purchases. You can attach receipt photos. All expenses are tracked for year-end tax deductions."))
        }
        if q.contains("inventory") || q.contains("stock") || q.contains("parts") {
            return withSearchResults(appResponse("Inventory", "The Inventory section tracks your supplies by vendor (SNS, Guardian). Items below threshold are marked for restocking. Track wire spools by footage remaining."))
        }
        if q.contains("closeout") || q.contains("close out") {
            return withSearchResults(appResponse("Closeout", "After completing a job, use Closeout to document: completion %, doorbell type, whip status, WAP locations, parts used, and photos. This sends a formatted email to scheduling."))
        }
        if q.contains("backup") || q.contains("icloud") || q.contains("sync") {
            return withSearchResults(appResponse("Backup & Sync", "Your data syncs automatically via iCloud to all your devices. You can also create manual backups in Settings > Backup to iCloud. Restore from backup if needed."))
        }
        if q.contains("tax") || q.contains("deduction") {
            return withSearchResults(appResponse("Taxes", "The Tax Summary shows your YTD gross income, deductions (mileage + expenses), net income, and estimated quarterly taxes. Self-employment tax is calculated at 15.3%."))
        }
        if q.contains("job") && (q.contains("add") || q.contains("new") || q.contains("create")) {
            return withSearchResults(appResponse("Adding Jobs", "Tap the green + button to add a new job. Enter the job number, lot, address, and subdivision. Add wire counts, enclosures, flat panels, etc. The total is calculated automatically."))
        }
        if q.contains("widget") {
            return withSearchResults(appResponse("Widgets", "Add PreWire Pro widgets to your home screen to see weekly earnings and job count at a glance. Widgets update automatically when you add or edit jobs."))
        }

        // General builder comparison
        if q.contains("difference") || q.contains("compare") || q.contains("which builder") {
            return withSearchResults(builderComparisonResponse())
        }

        // Search-only response if we have results but no knowledge match
        if !emailResults.isEmpty || !blueprintResults.isEmpty {
            return searchOnlyResponse(emailResults: emailResults, blueprintResults: blueprintResults)
        }

        // Default response
        return defaultResponse()
    }

    private func searchOnlyResponse(emailResults: [SearchResult], blueprintResults: [SearchResult]) -> AssistantResponse {
        var text = "I found some relevant information:\n"

        if !emailResults.isEmpty {
            text += "\n📧 From your emails:"
        }

        return AssistantResponse(
            text: text,
            relatedTopics: ["Search your emails", "Builder standards"],
            emailResults: emailResults,
            blueprintResults: blueprintResults
        )
    }

    // MARK: - Builder Responses

    private func miHomesResponse(_ q: String) -> AssistantResponse {
        if q.contains("dmark") {
            return AssistantResponse(
                text: "MI Homes DMARK:\n• Flex tube and 1 coax\n• Single outlet jblock\n• Flash sides and top\n• Coil wires inside and blank plate",
                relatedTopics: ["MI Homes wiring", "MI Homes enclosure"]
            )
        }
        if q.contains("wire") || q.contains("minimum") {
            return AssistantResponse(
                text: "MI Homes requires 5 WIRES MINIMUM.\n\nWiring specs:\n• Data Only ports\n• Dual ports in family room and owner's bedroom\n• 1 WAP\n• 1 hub keypad per print (if not marked, 4\" above garage entry light switch)\n• All exterior wall outlets must be in BLUE boxes\n• 9\" from corner or door frame",
                relatedTopics: ["MI Homes DMARK", "Blue boxes"]
            )
        }
        if q.contains("enclosure") || q.contains("onq") {
            return AssistantResponse(
                text: "MI Homes Enclosure:\n• 30 inch OnQ per print\n• Contact super for location questions\n• Scab 2x4 horizontally to corners if not attached to stud on both sides\n• Closet OnQs at 56\" AFF from top of OnQ",
                relatedTopics: ["MI Homes FPP", "MI Homes wiring"]
            )
        }
        if q.contains("fpp") || q.contains("flat panel") {
            return AssistantResponse(
                text: "MI Homes FPP:\n• 2 HDMI and pass through cat 6\n• OnQs in closet at 56\" AFF from top of OnQ",
                relatedTopics: ["MI Homes enclosure"]
            )
        }
        if q.contains("townhome") || q.contains("3 story") {
            return AssistantResponse(
                text: "MI Homes 3 Story Townhomes:\n• Tube ran to garage ceiling\n• 1 coax and 1 data ran to side of unit",
                relatedTopics: ["MI Homes DMARK"]
            )
        }
        // General MI Homes
        return AssistantResponse(
            text: "MI HOMES - 5 Wires Minimum\n\nDMARK: Flex tube + 1 coax, jblock, flash sides/top\n\nWIRING: Data only, dual ports in family room & owner's bedroom, 1 WAP, blue boxes on exterior walls\n\nENCLOSURE: 30\" OnQ per print, scab 2x4 if needed\n\nFPP: 2 HDMI + pass through cat 6",
            relatedTopics: ["MI Homes DMARK", "MI Homes wiring", "MI Homes enclosure"]
        )
    }

    private func pulteResponse(_ q: String) -> AssistantResponse {
        if q.contains("dmark") {
            return AssistantResponse(
                text: "Pulte DMARK:\n• FLEX TUBE ONLY (no coax)\n• Jblock with flash on sides and top\n• Brick exterior: Install jblock 8\" above brick line or even with bottom of electric meter",
                relatedTopics: ["Pulte enclosure", "Pulte wiring"]
            )
        }
        if q.contains("enclosure") || q.contains("onq") {
            return AssistantResponse(
                text: "Pulte Enclosure:\n• 30\" OnQ behind laundry door (unless basement)\n• If basement exists, enclosure MUST be there\n• Scab 2x4 to corners if not attached to stud\n• Closet OnQs at 56\" AFF from top\n\n**Stellar Floorplan: 52\" to bottom of enclosure",
                relatedTopics: ["Pulte DMARK", "Pulte FPP"]
            )
        }
        if q.contains("fpp") || q.contains("flat panel") {
            return AssistantResponse(
                text: "Pulte FPP:\n• 2 HDMI\n• Pass through cat 6\n• Tube",
                relatedTopics: ["Pulte enclosure"]
            )
        }
        if q.contains("model") || q.contains("office") || q.contains("kiosk") {
            return AssistantResponse(
                text: "Pulte Model Homes:\n• Office data lines homerun to office kiosk\n• Kiosk gets its own dmark run\n• 1 coax + 1 data from kiosk to enclosure location\n• Home wires homerun to enclosure",
                relatedTopics: ["Pulte enclosure"]
            )
        }
        if q.contains("contact") || q.contains("manager") || q.contains("super") {
            return AssistantResponse(
                text: "For Pulte construction manager contacts, go to:\nBuilders > Pulte Contacts tab\n\nYou can search by subdivision name and tap to call or email directly.",
                relatedTopics: ["Pulte standards"]
            )
        }
        // General Pulte
        return AssistantResponse(
            text: "PULTE HOMES - Flex Tube Only\n\nDMARK: Flex tube only (no coax), jblock, flash sides/top\n\nWIRING: Dual port in family room\n\nENCLOSURE: 30\" OnQ behind laundry door (or basement if exists)\n\nFPP: 2 HDMI + pass through cat 6 + tube\n\nTip: Use the Pulte Contacts tab in Builders to find your super's phone number.",
            relatedTopics: ["Pulte DMARK", "Pulte contacts", "Pulte enclosure"]
        )
    }

    private func beazerResponse(_ q: String) -> AssistantResponse {
        if q.contains("dmark") {
            return AssistantResponse(
                text: "Beazer DMARK:\n• Flex tube and 1 coax\n• Flash card\n• Jblock\n• FLEX TAPE on sides and top\n• Add bubble box at trim",
                relatedTopics: ["Beazer wiring", "Beazer enclosure"]
            )
        }
        if q.contains("wire") || q.contains("wiring") {
            return AssistantResponse(
                text: "Beazer Wiring:\n• Dual ports in family room, owner's bedroom, AND loft\n• ALL wires in BLUE boxes only",
                relatedTopics: ["Beazer DMARK", "Blue boxes"]
            )
        }
        if q.contains("enclosure") || q.contains("onq") {
            return AssistantResponse(
                text: "Beazer Enclosure:\n• 30\" OnQ marked on prints\n• Typically laundry room or owner's bedroom closet\n• Scab 2x4 to corners if not attached to stud\n• Closet OnQs at 56\" AFF from top",
                relatedTopics: ["Beazer FPP"]
            )
        }
        if q.contains("fpp") || q.contains("flat panel") {
            return AssistantResponse(
                text: "Beazer FPP:\n• TUBE ONLY\n• Use special enclosed nail in conduit box",
                relatedTopics: ["Beazer enclosure"]
            )
        }
        if q.contains("model") || q.contains("office") {
            return AssistantResponse(
                text: "Beazer Model Homes:\n• Wires run to enclosure\n• Office wires homerun in office to termination point\n• 1 coax + 1 data ran to dmark AND to enclosure from office homerun location",
                relatedTopics: ["Beazer enclosure"]
            )
        }
        // General Beazer
        return AssistantResponse(
            text: "BEAZER HOMES - Flex Tape\n\nDMARK: Flex tube + 1 coax, flash card, jblock, FLEX TAPE on sides/top, bubble box at trim\n\nWIRING: Dual ports in family room, owner's bedroom, AND loft. ALL wires in blue boxes only.\n\nENCLOSURE: 30\" OnQ per prints (usually laundry or owner's closet)\n\nFPP: Tube only, use enclosed nail in conduit box",
            relatedTopics: ["Beazer DMARK", "Beazer wiring", "Blue boxes"]
        )
    }

    private func dreesResponse(_ q: String) -> AssistantResponse {
        if q.contains("dmark") {
            return AssistantResponse(
                text: "Drees DMARK:\n• Flex tube and 1 coax\n• Flash card\n• Jblock and flash sides and top\n• Brick exterior: 8\" above brick line or even with electric meter\n• Bubble box added at trim\n• FLEXTAPE on jblock",
                relatedTopics: ["Drees wiring", "Drees enclosure"]
            )
        }
        if q.contains("wire") || q.contains("wiring") {
            return AssistantResponse(
                text: "Drees Wiring:\n• 4 wires any configuration\n• 1 WAP",
                relatedTopics: ["Drees DMARK", "Drees enclosure"]
            )
        }
        if q.contains("enclosure") || q.contains("onq") {
            return AssistantResponse(
                text: "Drees Enclosure:\n• 30\" OnQ in owner's bedroom closet\n• If basement: place under basement stairs\n• Scab 2x4 to corners if not attached to stud\n• Closet OnQs at 56\" AFF from top",
                relatedTopics: ["Drees FPP"]
            )
        }
        if q.contains("fpp") || q.contains("flat panel") {
            return AssistantResponse(
                text: "Drees FPP:\n• 2 HDMI and pass through cat 6\n• OR can be flex tube only - check contract",
                relatedTopics: ["Drees enclosure"]
            )
        }
        // General Drees
        return AssistantResponse(
            text: "DREES HOMES - Flextape on Jblock\n\nDMARK: Flex tube + 1 coax, flash card, jblock, FLEXTAPE on jblock, bubble box at trim\n\nWIRING: 4 wires any configuration, 1 WAP\n\nENCLOSURE: 30\" OnQ in owner's bedroom closet (or under basement stairs)\n\nFPP: 2 HDMI + pass through cat 6, or flex tube only (check contract)",
            relatedTopics: ["Drees DMARK", "Drees wiring", "Drees enclosure"]
        )
    }

    private func epconResponse(_ q: String) -> AssistantResponse {
        if q.contains("dmark") {
            return AssistantResponse(
                text: "Epcon DMARK:\n• Per contract - can be tube, wires, or both\n• Blue flash card\n• Zip tape flashing on sides and top\n\nCourtyards Westfield: Dmark must be tube + 1 coax + 1 data",
                relatedTopics: ["Epcon wiring", "Epcon enclosure"]
            )
        }
        if q.contains("wire") || q.contains("wiring") {
            return AssistantResponse(
                text: "Epcon Wiring:\n• 2 to 3 data marked on print\n• ALL wires must be in BLUE boxes (except FPPs)",
                relatedTopics: ["Epcon DMARK", "Blue boxes"]
            )
        }
        if q.contains("enclosure") || q.contains("onq") {
            return AssistantResponse(
                text: "Epcon Enclosure:\n• 30\" OnQ in closet\n• Centered in rear of closet, no higher than 68\" to top\n• CAN NOT BE ON EXTERIOR WALL OR WALL SHARED WITH GARAGE\n• Scab 2x4 to corners if not attached to stud\n• Closet OnQs at 56\" AFF from top",
                relatedTopics: ["Epcon FPP"]
            )
        }
        if q.contains("fpp") || q.contains("flat panel") {
            return AssistantResponse(
                text: "Epcon FPP:\n• 2 HDMIs, pass through cat 6, tube\n• Can be tube only - check contract",
                relatedTopics: ["Epcon enclosure"]
            )
        }
        if q.contains("courtyard") || q.contains("westfield") {
            return AssistantResponse(
                text: "Epcon Courtyards Westfield:\n• Dmark must be tube AND 1 coax AND 1 data",
                relatedTopics: ["Epcon DMARK"]
            )
        }
        // General Epcon
        return AssistantResponse(
            text: "EPCON HOMES - Blue Flash Card\n\nDMARK: Per contract (tube, wires, or both), blue flash card, zip tape on sides/top\n\nWIRING: 2-3 data per print, ALL wires in blue boxes (except FPPs)\n\nENCLOSURE: 30\" OnQ in closet, centered, max 68\" to top. NOT on exterior wall or garage wall!\n\nFPP: 2 HDMIs + pass through cat 6 + tube (or tube only per contract)\n\nCourtyards Westfield: Dmark = tube + 1 coax + 1 data",
            relatedTopics: ["Epcon DMARK", "Epcon wiring", "Blue boxes"]
        )
    }

    // MARK: - Topic Responses

    private func dmarkResponse(_ q: String) -> AssistantResponse {
        return AssistantResponse(
            text: "DMARK by Builder:\n\nMI Homes: Flex tube + 1 coax, jblock, flash sides/top\n\nPulte: FLEX TUBE ONLY (no coax), jblock, flash sides/top\n\nBeazer: Flex tube + 1 coax, jblock, FLEX TAPE, bubble box\n\nDrees: Flex tube + 1 coax, FLEXTAPE on jblock, bubble box\n\nEpcon: Per contract, blue flash card, zip tape",
            relatedTopics: ["MI Homes DMARK", "Pulte DMARK", "Beazer DMARK", "Drees DMARK", "Epcon DMARK"]
        )
    }

    private func enclosureResponse(_ q: String) -> AssistantResponse {
        return AssistantResponse(
            text: "ENCLOSURE by Builder:\n\nAll: 30\" OnQ, scab 2x4, 56\" AFF in closets\n\nMI Homes: Per print\n\nPulte: Behind laundry (or basement)\n\nBeazer: Per prints (laundry/owner's closet)\n\nDrees: Owner's bedroom closet (or under basement stairs)\n\nEpcon: In closet, max 68\" to top, NOT on exterior/garage wall",
            relatedTopics: ["MI Homes enclosure", "Pulte enclosure", "Beazer enclosure", "Drees enclosure", "Epcon enclosure"]
        )
    }

    private func fppResponse(_ q: String) -> AssistantResponse {
        return AssistantResponse(
            text: "FPP (Flat Panel Prep) by Builder:\n\nMI Homes: 2 HDMI + pass through cat 6\n\nPulte: 2 HDMI + pass through cat 6 + tube\n\nBeazer: TUBE ONLY, enclosed nail in conduit box\n\nDrees: 2 HDMI + cat 6, or tube only (check contract)\n\nEpcon: 2 HDMI + cat 6 + tube, or tube only (check contract)",
            relatedTopics: ["MI Homes FPP", "Pulte FPP", "Beazer FPP", "Drees FPP", "Epcon FPP"]
        )
    }

    private func wiringResponse(_ q: String) -> AssistantResponse {
        return AssistantResponse(
            text: "WIRING by Builder:\n\nMI Homes: 5 wires min, dual ports family/owner's bedroom, blue boxes exterior\n\nPulte: Dual port in family room\n\nBeazer: Dual ports family/bedroom/loft, ALL blue boxes\n\nDrees: 4 wires any config, 1 WAP\n\nEpcon: 2-3 data per print, ALL blue boxes (except FPPs)",
            relatedTopics: ["Blue boxes", "MI Homes wiring", "Beazer wiring", "Epcon wiring"]
        )
    }

    private func wapResponse(_ q: String) -> AssistantResponse {
        return AssistantResponse(
            text: "WAP (Wireless Access Point):\n\nMI Homes: 1 WAP required\nDrees: 1 WAP required\n\nFor closeout emails, note WAP locations:\n• uwap = upstairs WAP (e.g., \"outside mbr\")\n• dwap = downstairs WAP (e.g., \"hallway/kitchen\")",
            relatedTopics: ["MI Homes wiring", "Drees wiring", "Closeout"]
        )
    }

    private func blueBoxResponse(_ q: String) -> AssistantResponse {
        return AssistantResponse(
            text: "BLUE BOXES:\n\nMI Homes: EXTERIOR walls only in blue boxes\n\nBeazer: ALL wires in blue boxes\n\nEpcon: ALL wires in blue boxes (except FPPs)\n\nPulte: Standard boxes OK\n\nDrees: Not specified",
            relatedTopics: ["MI Homes wiring", "Beazer wiring", "Epcon wiring"]
        )
    }

    private func flextubeResponse(_ q: String) -> AssistantResponse {
        return AssistantResponse(
            text: "FLEX TUBE at DMARK:\n\nMI Homes: Flex tube + 1 coax\n\nPulte: FLEX TUBE ONLY (no coax)\n\nBeazer: Flex tube + 1 coax, FLEX TAPE\n\nDrees: Flex tube + 1 coax, FLEXTAPE on jblock\n\nEpcon: Per contract (tube, wires, or both)",
            relatedTopics: ["DMARK", "Beazer DMARK", "Drees DMARK", "Epcon DMARK"]
        )
    }

    private func jblockResponse(_ q: String) -> AssistantResponse {
        return AssistantResponse(
            text: "JBLOCK:\n\nMI Homes: Single outlet jblock\n\nPulte: Jblock + flash. Brick: 8\" above brick line\n\nBeazer: Jblock + flash card + flex tape\n\nDrees: Jblock + flash + FLEXTAPE on jblock\n\nEpcon: Blue flash card + zip tape",
            relatedTopics: ["DMARK"]
        )
    }

    private func builderComparisonResponse() -> AssistantResponse {
        return AssistantResponse(
            text: "BUILDER COMPARISON (5 builders):\n\n📍 DMARK:\n• MI, Beazer, Drees: Flex tube + coax\n• Pulte: Flex tube ONLY\n• Epcon: Per contract\n• Beazer/Drees: FLEX TAPE\n\n📦 ENCLOSURE:\n• All: 30\" OnQ, 56\" AFF in closet\n• Epcon: Max 68\" to top, NOT on exterior/garage wall\n\n📺 FPP:\n• MI, Pulte, Drees, Epcon: 2 HDMI + cat 6\n• Beazer: Tube only\n\n🔌 BLUE BOXES:\n• MI: Exterior walls only\n• Beazer, Epcon: ALL wires\n• Pulte, Drees: Standard OK",
            relatedTopics: ["MI Homes", "Pulte", "Beazer", "Drees", "Epcon"]
        )
    }

    // MARK: - App Responses

    private func appResponse(_ topic: String, _ text: String) -> AssistantResponse {
        return AssistantResponse(text: text, relatedTopics: [topic])
    }

    private func defaultResponse() -> AssistantResponse {
        return AssistantResponse(
            text: "I can help with:\n\n🏠 Builder Standards (5 builders)\n• MI Homes, Pulte, Beazer, Drees, Epcon\n• DMARK, wiring, enclosure, FPP specs\n\n📱 App Features\n• Adding jobs, invoices, mileage tracking\n• Expenses, inventory, closeout\n• Backup, sync, taxes, widgets\n\nTry asking:\n• \"What's the MI Homes wire minimum?\"\n• \"Pulte DMARK specs?\"\n• \"Drees enclosure location?\"\n• \"Which builders need blue boxes?\"",
            relatedTopics: ["MI Homes", "Pulte", "Beazer", "Drees", "Epcon"]
        )
    }
}
