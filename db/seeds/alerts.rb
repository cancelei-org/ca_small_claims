AlertLog.find_or_create_by!(event: "seed.test", severity: "warning", payload: { message: "alert seed" })
