import Foundation
import CoreGraphics
import CoreText
#if canImport(AppKit)
import AppKit
#endif

let outputPath = "Vachanam/Resources/Benchmark/The_Ultimate_Multi_Discipline_TTS_Benchmark.pdf"
let outputURL = URL(fileURLWithPath: outputPath)

// Page geometry: US Letter 612 x 792 pt
var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)

guard let consumer = CGDataConsumer(url: outputURL as CFURL),
      let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
    print("Failed to create PDF context")
    exit(1)
}

struct PageSection {
    let title: String
    let subtitle: String?
    let content: String
}

let pages: [[PageSection]] = [
    // PAGE 1: Overview & Section 1: The Novel
    [
        PageSection(
            title: "The Ultimate Multi-Discipline TTS Benchmark",
            subtitle: "A Rigorous Cross-Domain Speech Synthesis & Audio Evaluation Suite",
            content: """
This document serves as the official multi-discipline benchmark for evaluating on-device Neural Text-to-Speech (TTS), speech rule engines (SRE), prosodic phrasing, and scientific text normalization in Vachanam. It incorporates high-stress scenarios across narrative prose, advanced linear algebra with explicit matrices, empirical physical measurements, and scholarly academic citations.
"""
        ),
        PageSection(
            title: "Section 1: The Novel (Dialogue, Punctuation & Prosody)",
            subtitle: nil,
            content: """
The rain hammered against the stained-glass transom of Room 14, where Detective Clara Vance sat tracing the rim of an empty tumbler.

"He didn't just leave, Vance," Dr. Alistair whispered, his voice catching on the threshold of an apology. "He vanished—clean into thin air! At precisely 11:45 p.m., no less."

"Is that so?" Clara arched an eyebrow, leaning forward into the lamplight. "Then tell me, Alistair... why did the night porter find his spectacles—still warm—on the side table?"

A sudden, sharp crash echoed from the conservatory downstairs. Crash!

"Wait—did you hear that?" Alistair gasped, clutching his lapels. "Don't open that door!"

Clara clicked her revolver's cylinder into place with a dry, metallic snap. "Stay behind me. If anyone so much as twitches, take cover under the mahogany desk."

"Look here," Alistair breathed, his knuckles whitening against the cedar armoire; "he hasn't even retrieved his overcoat! It wasn't Alistair's fault—couldn't have been—not after what occurred o'clock last Tuesday. Did he truly mutter, 'Beware the Ides of November,' before slipping behind the velvet curtain?"

Tick-tock, tick-tock... The grandfather clock chimed midnight. Drip, drip, drip.

"Halt!" shouted Inspector Kensington from the damp corridor. "Drop the ledger and step into the light!"
"""
        )
    ],
    
    // PAGE 2: Section 2: Pure Mathematics & Formal Notation (Linear Algebra & Explicit Matrices)
    [
        PageSection(
            title: "Section 2: Pure Mathematics & Formal Notation",
            subtitle: "Part A: Linear Systems, Orthonormal Bases & Variational Estimators",
            content: """
Consider an arbitrary sequence of vectors x⃗₁, …, x⃗ₙ ∈ ℝⁿ defining an orthonormal basis. Let matrix A ∈ ℝᵐˣⁿ satisfy the linear system:
    A x⃗ = b⃗    (2.1)

The explicit component-wise expansion is written as:
    a₁₁ x₁ + a₁₂ x₂ + … + a₁ₙ xₙ = b₁

Where the general summation and continuous analogues satisfy:
    ∑ᵢ₌₁ⁿ xᵢ² = ‖x⃗‖²     and     ∫₀^∞ e^(−x²) dx = √π / 2

If the matrix determinant satisfies det(A) ≠ 0, the inverse exists such that A⁻¹ A = Iₙ. Furthermore, let x̂ denote the regularized estimator:
    x̂ = argmin_{x⃗}  ‖A x⃗ − b⃗‖₂² + λ ‖x⃗‖₁

For all ε > 0, there exists δ > 0 such that if 0 < |x − c| < δ, then:
    |f(x) − L| < ε   ⟹   lim_{x → c} f(x) = L
"""
        ),
        PageSection(
            title: "Part B: Explicit Matrices, SVD & Multivariable Operators",
            subtitle: nil,
            content: """
Let transformation matrix A and orthogonal rotation Q be expressed explicitly as:
    A =  [ 3  -1 ;  2   4 ]  ,     Q =  [ 1   0  -2 ;  0   3   4 ;  5  -1   0 ]

The determinant of the 2 by 2 system satisfies:
    det(A) =  | 3  -1 ;  2   4 |  = (3)(4) − (−1)(2) = 14 ≠ 0

For a general column vector x⃗ = [x₁, x₂, ⋮, xₙ]ᵀ ∈ ℝⁿ, the spectral theorem guarantees eigenvalue decomposition A v⃗ᵢ = λᵢ v⃗ᵢ. The Singular Value Decomposition (SVD) of matrix A factorizes as:
    A = U Σ Vᵀ = ∑ᵢ₌₁ʳ σᵢ u⃗ᵢ v⃗ᵢᵀ

With matrix trace tr(A) = ∑ᵢ₌₁ⁿ aᵢᵢ, Frobenius norm ‖A‖_F, tensor Kronecker product A ⊗ B, and direct sum V ⊕ W. In vector calculus, the flux across boundary ∂Ω satisfies Stokes' theorem:
    ∮_{∂Ω} F⃗ · dr⃗ = ∬_Ω (∇ × F⃗) · dS⃗
"""
        )
    ],
    
    // PAGE 3: Section 3: Empirical Science, SI Units & Measurements
    [
        PageSection(
            title: "Section 3: Empirical Science, SI Units & Measurements",
            subtitle: "Fundamental Physical Constants & Empirical Laboratory Metrics",
            content: """
Laboratory conditions were stabilized at 21.5°C (70.7°F) under an ambient atmospheric pressure of 101.3 kPa.

Fundamental Constants:
• Planck's Constant: h ≈ 6.626 × 10⁻³⁴ J·s  (ħ ≈ 1.055 × 10⁻³⁴ J·s)
• Boltzmann's Constant: k_B ≈ 1.381 × 10⁻²³ J/K
• Stefan-Boltzmann Constant: σ ≈ 5.670 × 10⁻⁸ W·m⁻²·K⁻⁴
• Vacuum Permittivity: ε₀ ≈ 8.854 × 10⁻¹² F/m
• Avogadro's Constant: N_A ≈ 6.022 × 10²³ mol⁻¹
• Elementary Charge: e = 1.602 × 10⁻¹⁹ C
• Speed of Light in Vacuum: c = 3.0 × 10⁸ m/s
• Acceleration Due to Gravity: g ≈ 9.8 m/s²

Experimental Protocol & Instrumentation:
During sample evaluation, the ultracentrifuge spun at 14,000 rpm for 45 min at 4°C, precipitating 250 mg of enzymatic substrate into 15.5 mL of buffer solution. Aliquots of 50 µL were diluted into 0.25 M Tris-HCl and 15 mM NaCl at pH 7.4 ± 0.05.

High-frequency RF excitation was maintained at 2.4 GHz across a 50 Ω matched transmission line, with a leakage threshold below 500 mA at 12 V and noise floor -110 dBm. Cryogenic specimens preserved at -196.0°C (77.1 K) exhibited observed spectral shifts measuring roughly 5 nm to 12 nm across a 100 ms capture window.
"""
        )
    ],
    
    // PAGE 4: Section 4: Academic Prose, Citations & Normalization
    [
        PageSection(
            title: "Section 4: Academic Prose, Citations & Normalization",
            subtitle: "Deep Acoustic Modeling, Statistical Significance & Currencies",
            content: """
Recent breakthroughs in deep acoustic modeling (e.g., Vaswani et al., 2017; see also Radford & colleagues, ca. 2022; Devlin et al., 2018) have rendered conventional concatenative speech synthesis obsolete. That is, end-to-end neural pipelines synthesize natural cadence directly from text tokens without manual formant tuning.

Refer to Figure 4A (p. 142, Vol. 12, No. 3) for ablation metrics comparing autoregressive vs. non-autoregressive decoders. See also Table 2B (col. 4, row 7) and Appendix A (pp. 312–325). More documentation is accessible at https://arxiv.org/abs/1706.03762 or through the official index via doi:10.1000/182.

As noted in ibid., p. 145, and op. cit., cf. Section 2.1 (§ 2.1, ¶ 3), the speech naturalness score scales monotonically with parameter budget (viz., without acoustic collapse).

The experimental cohort demonstrated significant improvements (t(118) = 4.87, p < 0.001, two-tailed t-test; F(3, 140) = 24.6, p = 0.0002) across all test runs:
• Trial A yielded a gain of +14.8% over baseline (n = 1,200 subjects, 95% CI [12.4%, 17.2%], R² = 0.942).
• Trial B showed a reduction of -3.2 dB in spectral distortion.

Equipment acquisition fees totaled $4,500, €3,200, £1,850, ¥250,000, and ₹75,000 respectively.

Approximately ¾ of all evaluated samples passed blind auditory screening with zero degradation (±0.05% variance). Over ⅞ of listeners preferred the on-device neural voice over legacy server-side synthesis.
"""
        )
    ]
]

// Styling constants & paragraph styles
let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 14.0, nil)
let subtitleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 10.5, nil)
let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 8.8, nil)
let headerFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 17.0, nil)

for (pageIndex, sections) in pages.enumerated() {
    context.beginPage(mediaBox: &mediaBox)
    
    let pageAttr = NSMutableAttributedString()
    
    // Header banner on Page 1
    if pageIndex == 0 {
        let bannerStyle = NSMutableParagraphStyle()
        bannerStyle.paragraphSpacing = 6.0
        let bannerAttr: [NSAttributedString.Key: Any] = [
            .font: CTFontCreateWithName("Helvetica-Bold" as CFString, 10.0, nil),
            .foregroundColor: CGColor(red: 0.85, green: 0.55, blue: 0.15, alpha: 1.0),
            .paragraphStyle: bannerStyle
        ]
        pageAttr.append(NSAttributedString(string: "VACHANAM NEURAL TTS BENCHMARK\n", attributes: bannerAttr))
    }
    
    for (sectionIndex, section) in sections.enumerated() {
        let isMainTitle = (pageIndex == 0 && sectionIndex == 0)
        
        // Title Style
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.paragraphSpacing = (section.subtitle != nil) ? 3.0 : 6.0
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: isMainTitle ? headerFont : titleFont,
            .foregroundColor: CGColor(red: 0.10, green: 0.14, blue: 0.22, alpha: 1.0),
            .paragraphStyle: titleStyle
        ]
        pageAttr.append(NSAttributedString(string: "\(section.title)\n", attributes: titleAttributes))
        
        // Subtitle Style
        if let sub = section.subtitle {
            let subStyle = NSMutableParagraphStyle()
            subStyle.paragraphSpacing = 6.0
            let subAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: CGColor(red: 0.35, green: 0.45, blue: 0.55, alpha: 1.0),
                .paragraphStyle: subStyle
            ]
            pageAttr.append(NSAttributedString(string: "\(sub)\n", attributes: subAttributes))
        }
        
        // Body Style
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 2.0
        bodyStyle.paragraphSpacing = 6.0
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: CGColor(red: 0.16, green: 0.20, blue: 0.26, alpha: 1.0),
            .paragraphStyle: bodyStyle
        ]
        pageAttr.append(NSAttributedString(string: "\(section.content)\n\n", attributes: bodyAttributes))
    }
    
    // Draw unified page content frame
    let framesetter = CTFramesetterCreateWithAttributedString(pageAttr)
    let contentRect = CGRect(x: 54, y: 50, width: 504, height: 690)
    let contentPath = CGPath(rect: contentRect, transform: nil)
    let contentFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), contentPath, nil)
    CTFrameDraw(contentFrame, context)
    
    // Draw clean footer frame
    let footerStyle = NSMutableParagraphStyle()
    footerStyle.alignment = .center
    let footerAttr: [NSAttributedString.Key: Any] = [
        .font: CTFontCreateWithName("Helvetica" as CFString, 8.5, nil),
        .foregroundColor: CGColor(red: 0.55, green: 0.60, blue: 0.65, alpha: 1.0),
        .paragraphStyle: footerStyle
    ]
    let footerString = NSAttributedString(
        string: "Vachanam Multi-Discipline TTS Benchmark • Page \(pageIndex + 1) of \(pages.count)",
        attributes: footerAttr
    )
    let footerFramesetter = CTFramesetterCreateWithAttributedString(footerString)
    let footerRect = CGRect(x: 54, y: 22, width: 504, height: 20)
    let footerPath = CGPath(rect: footerRect, transform: nil)
    let footerFrame = CTFramesetterCreateFrame(footerFramesetter, CFRangeMake(0, 0), footerPath, nil)
    CTFrameDraw(footerFrame, context)
    
    context.endPage()
}

context.closePDF()
print("Successfully generated \(outputPath)")
