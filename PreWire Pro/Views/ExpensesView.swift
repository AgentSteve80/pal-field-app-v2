//
//  ExpensesView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @State private var showingAddExpense = false
    @State private var selectedExpenseForReceipt: Expense?
    @State private var showingDeleteAlert = false
    @State private var expenseToDelete: Expense?

    // Filter by current user (empty ownerEmail = legacy data, treat as current user's)
    private var currentUserEmail: String {
        GmailAuthManager.shared.userEmail.lowercased()
    }

    private var expenses: [Expense] {
        allExpenses.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    // Filter states
    @State private var selectedCategory: String = "All"
    @State private var startDate: Date = {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }()
    @State private var endDate = Date()

    var categories = ["All"] + ExpenseCategory.allCases.map { $0.rawValue }

    var filteredExpenses: [Expense] {
        expenses.filter { expense in
            let categoryMatch = selectedCategory == "All" || expense.category == selectedCategory
            // Use end of day for endDate to include all expenses from that day
            let calendar = Calendar.current
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            let dateMatch = expense.date >= startDate && expense.date <= endOfDay
            return categoryMatch && dateMatch
        }
    }

    var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    var expensesByCategory: [String: Double] {
        var totals: [String: Double] = [:]
        for expense in filteredExpenses {
            totals[expense.category, default: 0] += expense.amount
        }
        return totals
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Expenses")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("$\(totalAmount, specifier: "%.2f")")
                                .font(.title.bold())
                                .foregroundStyle(.red)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(filteredExpenses.count) receipts")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Tax Deductible")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    // Category breakdown
                    if !expensesByCategory.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(expensesByCategory.sorted(by: { $0.value > $1.value }), id: \.key) { category, amount in
                                HStack {
                                    if let expCat = ExpenseCategory.allCases.first(where: { $0.rawValue == category }) {
                                        Image(systemName: expCat.icon)
                                            .foregroundStyle(Color(expCat.color))
                                    }
                                    Text(category)
                                        .font(.caption)
                                    Spacer()
                                    Text("$\(amount, specifier: "%.2f")")
                                        .font(.caption.bold())
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding()

                // Filters
                VStack(spacing: 12) {
                    HStack {
                        Text("Filter")
                            .font(.headline)
                        Spacer()
                    }

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        DatePicker("From", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                        Text("to")
                        DatePicker("To", selection: $endDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    .font(.caption)
                }
                .padding(.horizontal)

                // Expense List
                if filteredExpenses.isEmpty {
                    ContentUnavailableView(
                        "No Expenses",
                        systemImage: "receipt",
                        description: Text("Add expenses to track your tax deductions")
                    )
                    .onAppear {
                        print("📋 Total expenses in DB: \(expenses.count)")
                        print("📋 Filtered expenses: \(filteredExpenses.count)")
                        print("📋 Filter - Category: \(selectedCategory), Start: \(startDate), End: \(endDate)")
                    }
                } else {
                    List {
                        ForEach(filteredExpenses) { expense in
                            ExpenseRow(expense: expense)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if expense.receiptImageData != nil {
                                        selectedExpenseForReceipt = expense
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        expenseToDelete = expense
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
            }
            .sheet(item: $selectedExpenseForReceipt) { expense in
                if let imageData = expense.receiptImageData,
                   let uiImage = UIImage(data: imageData) {
                    ReceiptImageView(image: uiImage, expense: expense)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Unable to load receipt image")
                            .font(.headline)
                        Button("Dismiss") {
                            selectedExpenseForReceipt = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .alert("Delete Expense?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let expense = expenseToDelete {
                        deleteExpense(expense)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let expense = expenseToDelete {
                    Text("Are you sure you want to delete this \(expense.category) expense for $\(expense.amount, specifier: "%.2f")?")
                }
            }
        }
    }

    private func deleteExpense(_ expense: Expense) {
        modelContext.delete(expense)
        try? modelContext.save()
    }
}

// MARK: - Expense Row

struct ExpenseRow: View {
    let expense: Expense

    var category: ExpenseCategory? {
        ExpenseCategory.allCases.first { $0.rawValue == expense.category }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            if let category = category {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color(category.color))
                    .cornerRadius(10)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.category)
                    .font(.headline)

                if !expense.merchant.isEmpty {
                    Text(expense.merchant)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(expense.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if expense.receiptImageData != nil {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            Text("$\(expense.amount, specifier: "%.2f")")
                .font(.title3.bold())
                .foregroundStyle(.red)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Receipt Image View

struct ReceiptImageView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let expense: Expense

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(expense.category)
                                .font(.headline)
                            Spacer()
                            Text("$\(expense.amount, specifier: "%.2f")")
                                .font(.title2.bold())
                                .foregroundStyle(.red)
                        }

                        if !expense.merchant.isEmpty {
                            Text(expense.merchant)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text(expense.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !expense.notes.isEmpty {
                            Text(expense.notes)
                                .font(.body)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
