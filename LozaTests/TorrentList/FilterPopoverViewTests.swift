//
//  FilterPopoverViewTests.swift
//  LozaTests
//
//  Created by Roman Simenok on 05.11.2026.
//

import Testing
import SwiftUI
@testable import Loza

@Suite("FilterPopoverView Tests")
@MainActor
struct FilterPopoverViewTests {
    @Test("ViewModel status toggle updates selection state for filter row")
    func testStatusToggleUpdatesSelection() {
        let viewModel = TorrentListViewModel()
        #expect(viewModel.selectedStatuses.isEmpty)
        #expect(!viewModel.hasActiveFilters)

        viewModel.toggleStatus(.downloading)
        #expect(viewModel.selectedStatuses.contains(.downloading))
        #expect(viewModel.hasActiveFilters)

        viewModel.toggleStatus(.downloading)
        #expect(!viewModel.selectedStatuses.contains(.downloading))
        #expect(!viewModel.hasActiveFilters)
    }

    @Test("FilterPopoverView initializes without runtime errors")
    func testFilterPopoverInitialization() {
        let viewModel = TorrentListViewModel()
        let view = FilterPopoverView(viewModel: viewModel)
        #expect(view.body != nil)
    }
}
