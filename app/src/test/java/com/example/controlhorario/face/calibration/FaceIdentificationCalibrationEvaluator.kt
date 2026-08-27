package com.example.controlhorario.face.calibration

import java.util.Locale

/**
 * Synthetic, labeled score sample for technical 1:N evaluation only.
 * A null expected label represents a controlled, non-enrolled impostor probe.
 */
internal data class SyntheticLabeledScoreSample(
    val sampleId: String,
    val expectedSubjectLabel: String?,
    val templateScores: List<SyntheticTemplateScore>,
)

internal data class SyntheticTemplateScore(
    val subjectLabel: String,
    val templateLabel: String,
    val score: Float,
)

internal data class FaceCalibrationSampleMetrics(
    val sampleId: String,
    val expectedSubjectLabel: String?,
    val topSubjectLabel: String,
    val genuineScore: Float?,
    val impostorScore: Float?,
    val topScore: Float,
    val secondScore: Float?,
    val gap: Float?,
)

internal data class FaceCalibrationCandidateMetrics(
    val margin: Float,
    val far: Double,
    val frr: Double,
    val falseAccepts: Int,
    val falseRejects: Int,
    val genuineAttempts: Int,
    val impostorAttempts: Int,
    val misidentifications: Int,
)

internal enum class FaceCalibrationStatus {
    TECHNICAL_SYNTHETIC_EVALUATION,
    INSUFFICIENT_CALIBRATION_DATA,
}

internal data class FaceCalibrationReport(
    val status: FaceCalibrationStatus,
    val matchThreshold: Float,
    val sampleCount: Int,
    val samples: List<FaceCalibrationSampleMetrics>,
    val candidates: List<FaceCalibrationCandidateMetrics>,
) {
    fun render(): String = buildString {
        appendLine("FACE_IDENTIFICATION_1N_CALIBRATION_REPORT")
        appendLine("status=$status")
        appendLine("evaluationScope=TECHNICAL_SYNTHETIC_DATA")
        appendLine("operationalCalibration=FUTURE_REQUIRES_AUTHORIZED_REPRESENTATIVE_DATA")
        appendLine("operationalMarginRecommendation=NONE")
        appendLine("threshold=${matchThreshold.formatMetric()}")
        appendLine("sampleCount=$sampleCount")
        samples.forEachIndexed { index, sample ->
            appendLine(
                "sample=${index + 1} " +
                    "genuine=${sample.genuineScore.formatMetric()} " +
                    "impostor=${sample.impostorScore.formatMetric()} " +
                    "top=${sample.topScore.formatMetric()} " +
                    "second=${sample.secondScore.formatMetric()} " +
                    "gap=${sample.gap.formatMetric()}"
            )
        }
        if (candidates.isEmpty()) {
            appendLine("marginCandidates=NONE")
        } else {
            appendLine("marginCandidates=${candidates.size}")
            candidates.forEach { candidate ->
                appendLine(
                    "candidate=${candidate.margin.formatMetric()} " +
                        "FAR=${candidate.far.formatRate()} " +
                        "FRR=${candidate.frr.formatRate()} " +
                        "falseAccepts=${candidate.falseAccepts} " +
                        "falseRejects=${candidate.falseRejects} " +
                        "misidentifications=${candidate.misidentifications}"
                )
            }
        }
        append("notice=CANDIDATES_ARE_OBSERVED_GAPS_NOT_AN_OPERATIONAL_RECOMMENDATION")
    }
}

/**
 * Pure test infrastructure. It consumes synthetic score matrices and never persists data.
 */
internal object FaceIdentificationCalibrationEvaluator {
    fun evaluate(
        samples: List<SyntheticLabeledScoreSample>,
        matchThreshold: Float,
    ): FaceCalibrationReport {
        require(matchThreshold.isFinite() && matchThreshold in -1f..1f) {
            "invalid_face_match_threshold"
        }
        require(samples.map { it.sampleId }.all(String::isNotBlank)) { "blank_sample_id" }
        require(samples.map { it.sampleId }.distinct().size == samples.size) { "duplicate_sample_id" }

        val metrics = samples.map(::evaluateSample)
        val enrolledLabels = samples.flatMap { sample ->
            sample.templateScores.map(SyntheticTemplateScore::subjectLabel)
        }.toSet()
        val genuineAttempts = metrics.count { it.expectedSubjectLabel != null }
        val impostorAttempts = metrics.count { it.expectedSubjectLabel == null }
        val expectedLabelsAvailable = metrics
            .filter { it.expectedSubjectLabel != null }
            .all { it.genuineScore != null }
        val completeRankings = metrics.all { it.secondScore != null && it.gap != null }
        val observedCandidates = metrics.mapNotNull { sample ->
            val second = sample.secondScore ?: return@mapNotNull null
            val gap = sample.gap ?: return@mapNotNull null
            gap.takeIf { sample.topScore >= matchThreshold && second >= matchThreshold }
        }.distinct().sorted()
        val candidates = observedCandidates.map { margin ->
            evaluateCandidate(metrics, matchThreshold, margin)
        }
        val sufficient = enrolledLabels.size >= 2 &&
            genuineAttempts > 0 &&
            impostorAttempts > 0 &&
            expectedLabelsAvailable &&
            completeRankings &&
            candidates.isNotEmpty()

        return FaceCalibrationReport(
            status = if (sufficient) {
                FaceCalibrationStatus.TECHNICAL_SYNTHETIC_EVALUATION
            } else {
                FaceCalibrationStatus.INSUFFICIENT_CALIBRATION_DATA
            },
            matchThreshold = matchThreshold,
            sampleCount = metrics.size,
            samples = metrics,
            candidates = candidates,
        )
    }

    private fun evaluateSample(sample: SyntheticLabeledScoreSample): FaceCalibrationSampleMetrics {
        require(sample.templateScores.isNotEmpty()) { "empty_template_scores" }
        require(sample.templateScores.all { it.subjectLabel.isNotBlank() }) { "blank_subject_label" }
        require(sample.templateScores.all { it.templateLabel.isNotBlank() }) { "blank_template_label" }
        require(sample.templateScores.all { it.score.isFinite() && it.score in -1f..1f }) {
            "invalid_template_score"
        }
        // Runtime parity: ambiguity compares employees, not template rows. Preserve only
        // the strongest template for each employee before choosing top and second.
        val ranked = sample.templateScores
            .groupBy(SyntheticTemplateScore::subjectLabel)
            .mapNotNull { (_, candidates) -> candidates.maxByOrNull(SyntheticTemplateScore::score) }
            .sortedByDescending(SyntheticTemplateScore::score)
        val top = ranked.first()
        val second = ranked.getOrNull(1)
        val expected = sample.expectedSubjectLabel
        val genuine = expected?.let { expectedLabel ->
            ranked.firstOrNull { it.subjectLabel == expectedLabel }?.score
        }
        val impostor = ranked.firstOrNull {
            expected == null || it.subjectLabel != expected
        }?.score

        return FaceCalibrationSampleMetrics(
            sampleId = sample.sampleId,
            expectedSubjectLabel = expected,
            topSubjectLabel = top.subjectLabel,
            genuineScore = genuine,
            impostorScore = impostor,
            topScore = top.score,
            secondScore = second?.score,
            gap = second?.let { top.score - it.score },
        )
    }

    private fun evaluateCandidate(
        samples: List<FaceCalibrationSampleMetrics>,
        matchThreshold: Float,
        margin: Float,
    ): FaceCalibrationCandidateMetrics {
        var falseAccepts = 0
        var falseRejects = 0
        var genuineAttempts = 0
        var impostorAttempts = 0
        var misidentifications = 0

        samples.forEach { sample ->
            val accepted = sample.topScore >= matchThreshold && !(
                sample.secondScore != null &&
                    sample.secondScore >= matchThreshold &&
                    sample.gap != null &&
                    sample.gap <= margin
                )
            val expected = sample.expectedSubjectLabel
            if (expected == null) {
                impostorAttempts += 1
                if (accepted) falseAccepts += 1
            } else {
                genuineAttempts += 1
                val correctlyIdentified = accepted && sample.topSubjectLabel == expected
                if (!correctlyIdentified) falseRejects += 1
                if (accepted && sample.topSubjectLabel != expected) misidentifications += 1
            }
        }

        return FaceCalibrationCandidateMetrics(
            margin = margin,
            far = falseAccepts.rate(impostorAttempts),
            frr = falseRejects.rate(genuineAttempts),
            falseAccepts = falseAccepts,
            falseRejects = falseRejects,
            genuineAttempts = genuineAttempts,
            impostorAttempts = impostorAttempts,
            misidentifications = misidentifications,
        )
    }
}

private fun Int.rate(total: Int): Double = if (total == 0) Double.NaN else toDouble() / total

private fun Float?.formatMetric(): String = this?.let {
    String.format(Locale.US, "%.6f", it)
} ?: "N/A"

private fun Double.formatRate(): String = if (isNaN()) "N/A" else String.format(Locale.US, "%.6f", this)
