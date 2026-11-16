#!/fragment/sh

base_uri=https://www.familyopera.org/drupal
# chorus_uri="${base_uri}"/..._Practice_Materials
# Space Opera has two main chorus pages:
rebels_uri="${base_uri}"/Space_Opera_2019_Rebel_Practice_MP3s
empire_uri="${base_uri}"/Space_Opera_2019_Stormtrooper_Practice_MP3s
solo_uri="${base_uri}"/Space_Opera_2019_Principal_Soloists_Practice_MP3s
demo_uri="${base_uri}"/Space_Opera_2019_Demo_and_Orchestra_MP3s
orch_uri="${base_uri}"/Space_Opera_2019_Demo_and_Orchestra_MP3s
pdf_uri="${base_uri}"/Space_Opera_2027_Libretto_and_Score
video_uri="${base_uri}"/Space_Opera_2027_Choreography_Videos

html_dir=html
mp3_dir=mp3
pdf_dir=pdf
video_dir=video

labeled_music_uris=(
    # "${chorus_uri}" chorus
    "${rebels_uri}" rebels
    "${empire_uri}" empire
    "${solo_uri}" solo
    "${demo_uri}" demo
    "${demo_uri}" orch

)
labeled_video_uris=(
    "${video_uri}" video
)
labeled_pdf_uris=(
    "${pdf_uri}" pdf
)
labeled_uris=(
    "${labeled_music_uris[@]}"
    "${labeled_video_uris[@]}"
    "${labeled_pdf_uris[@]}"
)
